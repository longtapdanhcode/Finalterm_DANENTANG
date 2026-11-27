import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_inventory_edge_ai/features/edge_vision/domain/entities/detection.dart';
import 'package:field_inventory_edge_ai/features/edge_vision/domain/segmentation_mask.dart';
import 'package:field_inventory_edge_ai/features/edge_vision/domain/yolo_box_decoder.dart';

/// Proto 2 kênh, cạnh 10: kênh 0 dương trong ô [x0,x1)×[y0,y1), âm ở ngoài;
/// kênh 1 luôn 1 (dùng để dời ngưỡng).
MaskPrototypes protos({
  required int x0,
  required int x1,
  required int y0,
  required int y1,
  bool channelsLast = false,
}) {
  const size = 10, channels = 2;
  final data = Float32List(channels * size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final inside = x >= x0 && x < x1 && y >= y0 && y < y1;
      final v0 = inside ? 1.0 : -1.0;
      if (channelsLast) {
        data[(y * size + x) * channels] = v0;
        data[(y * size + x) * channels + 1] = 1;
      } else {
        data[y * size + x] = v0;
        data[size * size + y * size + x] = 1;
      }
    }
  }
  return MaskPrototypes(
    data,
    channels: channels,
    size: size,
    channelsLast: channelsLast,
  );
}

Detection box(
  double cx,
  double cy,
  double w,
  double h, [
  List<double> c = const [4, 0],
]) => Detection(
  classIndex: 0,
  label: 'Vết nứt',
  score: 0.9,
  cx: cx,
  cy: cy,
  w: w,
  h: h,
  maskCoefficients: c,
);

void main() {
  test('Diện tích mask = số điểm / tổng điểm ô proto', () {
    // Mask thật 4×2 điểm, khung phủ cả ô ảnh.
    final p = protos(x0: 2, x1: 6, y0: 3, y1: 5);
    final d = p.measure(box(0.5, 0.5, 1, 1))!;
    expect(d.maskArea, closeTo(8 / 100, 1e-9));
    // 2 hàng, 4 cột => √(4 + 16) / 10
    expect(d.maskLength, closeTo(0.4472, 1e-4));
  });

  test('Mask bị cắt theo khung phát hiện', () {
    final p = protos(x0: 0, x1: 10, y0: 0, y1: 10);
    // Khung 0.3 × 0.2 ở góc trên trái => 3 × 2 điểm.
    final d = p.measure(box(0.15, 0.1, 0.3, 0.2))!;
    expect(d.maskArea, closeTo(6 / 100, 1e-9));
  });

  test('NHWC cho cùng kết quả', () {
    final a = protos(x0: 2, x1: 6, y0: 3, y1: 5);
    final b = protos(x0: 2, x1: 6, y0: 3, y1: 5, channelsLast: true);
    final d = box(0.5, 0.5, 1, 1);
    expect(b.measure(d)!.maskArea, a.measure(d)!.maskArea);
  });

  test('Ngưỡng xác suất 0.5: logit âm không vào mask', () {
    final p = protos(x0: 2, x1: 6, y0: 3, y1: 5);
    // logit = 4·v0 - 5 < 0 ở mọi điểm.
    final d = p.measure(box(0.5, 0.5, 1, 1, const [4, -5]))!;
    expect(d.maskArea, 0);
    expect(d.maskLength, 0);
  });

  test('Không có hệ số mask: giữ nguyên vùng phát hiện', () {
    final p = protos(x0: 2, x1: 6, y0: 3, y1: 5);
    const plain = Detection(
      classIndex: 0,
      label: '',
      score: 1,
      cx: 0.5,
      cy: 0.5,
      w: 1,
      h: 1,
    );
    expect(p.measure(plain), isNull);
    expect(p.measureAll(const [plain]).single.hasMask, isFalse);
  });

  test('Bộ giải mã gắn hệ số mask của đúng ô được giữ', () {
    // 2 lớp, 2 hệ số mask, 2 ô: ô 1 điểm cao hơn.
    final out = [
      [0.2, 0.7], // cx
      [0.5, 0.5], // cy
      [0.2, 0.2], // w
      [0.2, 0.2], // h
      [0.6, 0.9], // điểm lớp 0
      [0.0, 0.0], // điểm lớp 1
      [1.0, 3.0], // hệ số 0
      [2.0, 4.0], // hệ số 1
    ];
    final d = decodeYoloBoxes(
      out,
      const ['a', 'b'],
      thresholdFor: (_) => 0.5,
      maskChannels: 2,
    );
    expect(d, hasLength(2));
    expect(d.first.maskCoefficients, [3.0, 4.0]);
    expect(d.last.maskCoefficients, [1.0, 2.0]);
  });
}
