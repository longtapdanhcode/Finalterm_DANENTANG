import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:field_inventory_edge_ai/core/ai_pipeline/ai_config.dart';

const _modelPath = AiConfig.modelPath;
const _inputSize = 640;
const _anchors = 8400;
const _prototypeCount = 32;
const _maskSize = 160;
const _labels = ['Vết nứt', 'Thấm mốc', 'Bong sơn', 'Gỉ sét'];
final _detectionChannels = 4 + _labels.length + _prototypeCount;

bool get supportsDamageSegmentation => Platform.isAndroid || Platform.isIOS;

Future<({Uint8List image, List<String> labels})> analyzeDamagePhoto(
  Uint8List photo,
) async {
  final model = await rootBundle.load(_modelPath);
  return compute(_analyze, (
    model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
    photo,
  ));
}

({Uint8List image, List<String> labels}) _analyze(
  (Uint8List, Uint8List) request,
) {
  final (model, photo) = request;
  final decoded = img.decodeImage(photo);
  if (decoded == null) throw const FormatException('Không đọc được ảnh.');

  final oriented = img.bakeOrientation(decoded);
  final scale = _inputSize / math.max(oriented.width, oriented.height);
  final width = math.max(1, (oriented.width * scale).round());
  final height = math.max(1, (oriented.height * scale).round());
  final resized = img
      .copyResize(
        oriented,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      )
      .convert(format: img.Format.uint8, numChannels: 3);
  final padX = (_inputSize - width) ~/ 2;
  final padY = (_inputSize - height) ~/ 2;
  const plane = _inputSize * _inputSize;
  final input = Float32List(3 * plane)..fillRange(0, 3 * plane, 114 / 255);
  for (final pixel in resized) {
    final index = (pixel.y + padY) * _inputSize + pixel.x + padX;
    input[index] = pixel.rNormalized.toDouble();
    input[plane + index] = pixel.gNormalized.toDouble();
    input[2 * plane + index] = pixel.bNormalized.toDouble();
  }

  final scores = Float32List(_detectionChannels * _anchors);
  final prototypes = Float32List(_prototypeCount * _maskSize * _maskSize);
  final options = InterpreterOptions()..threads = 4;
  try {
    final interpreter = Interpreter.fromBuffer(model, options: options);
    try {
      final outputs = interpreter.getOutputTensors();
      if (!listEquals(interpreter.getInputTensor(0).shape, [
            1,
            3,
            _inputSize,
            _inputSize,
          ]) ||
          outputs.length != 2 ||
          !listEquals(outputs[0].shape, [1, _detectionChannels, _anchors]) ||
          !listEquals(outputs[1].shape, [
            1,
            _prototypeCount,
            _maskSize,
            _maskSize,
          ])) {
        throw const FormatException('Định dạng model phân vùng không hợp lệ.');
      }
      interpreter.runForMultipleInputs(
        [input.buffer],
        {0: scores.buffer, 1: prototypes.buffer},
      );
    } finally {
      interpreter.close();
    }
  } finally {
    options.delete();
  }

  final labels = paintDamageMasks(resized, scores, prototypes, padX, padY);
  return (
    image: labels.isEmpty ? photo : img.encodePng(resized),
    labels: labels,
  );
}

typedef _Detection = ({
  int anchor,
  int label,
  double score,
  double left,
  double top,
  double right,
  double bottom,
});

double _overlap(_Detection a, _Detection b) {
  final width = math.min(a.right, b.right) - math.max(a.left, b.left);
  final height = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
  if (width <= 0 || height <= 0) return 0;
  final intersection = width * height;
  return intersection /
      ((a.right - a.left) * (a.bottom - a.top) +
          (b.right - b.left) * (b.bottom - b.top) -
          intersection);
}

/// Giải mã mask trong hệ tọa độ ảnh đã thu nhỏ, có bù phần đệm letterbox.
@visibleForTesting
List<String> paintDamageMasks(
  img.Image photo,
  Float32List scores,
  Float32List prototypes,
  int padX,
  int padY,
) {
  double value(int channel, int anchor) => scores[channel * _anchors + anchor];
  final candidates = <_Detection>[];
  for (var anchor = 0; anchor < _anchors; anchor++) {
    var label = 0;
    for (var i = 1; i < _labels.length; i++) {
      if (value(4 + i, anchor) > value(4 + label, anchor)) label = i;
    }
    final score = value(4 + label, anchor);
    if (!score.isFinite || score < 0.3) continue;
    final cx = value(0, anchor);
    final cy = value(1, anchor);
    final halfWidth = value(2, anchor) / 2;
    final halfHeight = value(3, anchor) / 2;
    final left = math.max(padX.toDouble(), cx - halfWidth);
    final top = math.max(padY.toDouble(), cy - halfHeight);
    final right = math.min((padX + photo.width).toDouble(), cx + halfWidth);
    final bottom = math.min((padY + photo.height).toDouble(), cy + halfHeight);
    if (!(left < right && top < bottom)) continue;
    candidates.add((
      anchor: anchor,
      label: label,
      score: score,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    ));
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));

  const stride = _inputSize ~/ _maskSize;
  const maskPlane = _maskSize * _maskSize;
  final overlay = Uint8List(maskPlane);
  final kept = <_Detection>[];
  final found = <String, double>{};
  for (final region in candidates) {
    // shortcut: giới hạn 20 vùng để xem nhanh, bỏ giới hạn này khi cần đo toàn bộ.
    if (kept.length == 20) break;
    if (kept.any((r) => r.label == region.label && _overlap(r, region) > 0.5)) {
      continue;
    }
    var visible = false;
    for (
      var y = (region.top / stride).ceil();
      y < region.bottom / stride;
      y++
    ) {
      for (
        var x = (region.left / stride).ceil();
        x < region.right / stride;
        x++
      ) {
        final pixel = y * _maskSize + x;
        var logit = 0.0;
        for (var c = 0; c < _prototypeCount; c++) {
          logit +=
              value(4 + _labels.length + c, region.anchor) *
              prototypes[c * maskPlane + pixel];
        }
        if (logit <= 0 || !logit.isFinite) continue;
        overlay[pixel] = 1;
        visible = true;
      }
    }
    if (!visible) continue;
    kept.add(region);
    found.putIfAbsent(_labels[region.label], () => region.score);
  }

  for (final pixel in photo) {
    final x = (pixel.x + padX) ~/ stride;
    final y = (pixel.y + padY) ~/ stride;
    if (overlay[y * _maskSize + x] == 0) continue;
    pixel
      ..r = (pixel.r * 0.55 + 255 * 0.45).round()
      ..g = (pixel.g * 0.55 + 150 * 0.45).round()
      ..b = (pixel.b * 0.55 + 40 * 0.45).round();
  }
  return [
    for (final entry in found.entries)
      '${entry.key} (${(entry.value * 100).toStringAsFixed(0)}%)',
  ];
}
