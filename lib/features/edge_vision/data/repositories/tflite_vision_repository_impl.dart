import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/ai_pipeline/ai_config.dart';
import '../../domain/repositories/vision_ai_repository.dart';

part 'tflite_vision_repository_impl.g.dart';

class TfliteVisionRepositoryImpl implements VisionAiRepository {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<void> loadModel() async {
    try {
      // 1. Kiểm tra kích thước file model trước khi nạp vào C++ Interpreter
      final ByteData modelData = await rootBundle.load(AiConfig.modelPath);
      if (modelData.lengthInBytes == 0) {
        debugPrint(
          '[VisionAI] Model file is empty (placeholder), skipping AI inference',
        );
        _isModelLoaded = false;
        return;
      }

      // 2. Khởi tạo TFLite Interpreter từ assets
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        AiConfig.modelPath,
        options: options,
      );
      _isModelLoaded = true;
      debugPrint('[VisionAI] TFLite model loaded successfully');

      // 3. Đọc nhãn phân loại nếu có
      final String labelData = await rootBundle.loadString(AiConfig.labelPath);
      if (labelData.trim().isNotEmpty) {
        _labels = labelData
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[VisionAI] Model file is empty or invalid, skipping AI inference: $e',
      );
      _isModelLoaded = false;
    }
  }

  @override
  Future<List<String>> analyzeFrame(
    List<int> imageBytes,
    int width,
    int height,
  ) async {
    if (!_isModelLoaded || _interpreter == null) {
      return const [];
    }

    try {
      // Decode byte ảnh sang Image format
      final img.Image? decoded = img.decodeImage(
        Uint8List.fromList(imageBytes),
      );
      if (decoded == null) {
        return const [];
      }

      final input = _toInputTensor(decoded);
      final classCount = _labels.length;
      final channels = 4 + classCount;
      final output = [
        List.generate(channels, (_) => List<double>.filled(_anchorCount, 0.0)),
      ];

      // Chạy inference
      _interpreter!.run(input, output);

      return decodeDetections(output[0], _labels);
    } catch (e) {
      debugPrint('[VisionAI] analyzeFrame error: $e');
      return const [];
    }
  }

  /// Số ô dự đoán của YOLO ở đầu vào 640x640.
  static const int _anchorCount = 8400;

  /// Letterbox ảnh về vuông (nền xám 114 như lúc huấn luyện) rồi chuyển sang
  /// tensor float32 dạng NCHW, giá trị 0..1.
  Object _toInputTensor(img.Image source) {
    const size = AiConfig.inputSize;
    final scale =
        size / (source.width > source.height ? source.width : source.height);
    final w = (source.width * scale).round().clamp(1, size);
    final h = (source.height * scale).round().clamp(1, size);
    final resized = img.copyResize(source, width: w, height: h);
    final dx = (size - w) ~/ 2;
    final dy = (size - h) ~/ 2;

    const plane = size * size;
    final data = Float32List(3 * plane)..fillRange(0, 3 * plane, 114 / 255.0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final pixel = resized.getPixel(x, y);
        final i = (y + dy) * size + (x + dx);
        data[i] = pixel.r / 255.0;
        data[plane + i] = pixel.g / 255.0;
        data[2 * plane + i] = pixel.b / 255.0;
      }
    }
    return data.reshape([1, 3, size, size]);
  }

  /// Chọn kết quả từ đầu ra YOLO [channels][anchors]: mỗi nhãn lấy điểm cao
  /// nhất, bỏ qua nếu thấp hơn ngưỡng của nhóm, sắp xếp giảm dần theo điểm.
  @visibleForTesting
  static List<String> decodeDetections(
    List<List<double>> output,
    List<String> labels,
  ) {
    final best = <int, double>{};
    for (var c = 0; c < labels.length && 4 + c < output.length; c++) {
      final threshold = AiConfig.defectClassIndexes.contains(c)
          ? AiConfig.defectConfidenceThreshold
          : AiConfig.confidenceThreshold;
      var top = 0.0;
      for (final score in output[4 + c]) {
        if (score > top) top = score;
      }
      if (top >= threshold) best[c] = top;
    }
    final order = best.keys.toList()
      ..sort((a, b) => best[b]!.compareTo(best[a]!));
    return [
      for (final c in order)
        '${labels[c]} (${(best[c]! * 100).toStringAsFixed(1)}%)',
    ];
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}

@riverpod
VisionAiRepository visionAiRepository(Ref ref) {
  final repository = TfliteVisionRepositoryImpl();
  ref.onDispose(() {
    repository.close();
  });
  return repository;
}
