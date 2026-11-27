import 'dart:math' as math;
import 'dart:typed_data';

import 'entities/detection.dart';

/// Bộ proto mask của YOLOv8-seg: [channels] ảnh [size]×[size] (thường
/// 32 × 160 × 160), ứng với toàn bộ ô ảnh vào AI.
class MaskPrototypes {
  const MaskPrototypes(
    this.data, {
    this.channels = 32,
    this.size = 160,
    this.channelsLast = false,
  });

  /// Giá trị proto, dạng phẳng NCHW ([channels][size][size]) hoặc NHWC
  /// ([size][size][channels]) khi [channelsLast].
  final Float32List data;
  final int channels;
  final int size;
  final bool channelsLast;

  /// Giá trị proto [k] tại điểm (x, y).
  double at(int k, int y, int x) => channelsLast
      ? data[(y * size + x) * channels + k]
      : data[(k * size + y) * size + x];

  /// Gắn số đo mask cho các vùng có hệ số mask; vùng khác giữ nguyên.
  List<Detection> measureAll(List<Detection> detections) => [
    for (final d in detections) measure(d) ?? d,
  ];

  /// Tính mask của [d] (chỉ trong khung của nó, như ultralytics) rồi đo:
  /// - diện tích = số điểm mask / tổng số điểm của ô proto;
  /// - chiều dài = √(số hàng² + số cột²) có mask, / cạnh ô proto. Với vết
  ///   nứt mảnh, đây là chiều dài đường chéo phần mask thật, sát hơn đường
  ///   chéo khung khi vết nứt cong hoặc khung rộng hơn vết.
  ///
  /// `null` khi [d] không có hệ số mask hợp lệ.
  Detection? measure(Detection d, {double threshold = 0.5}) {
    final coefficients = d.maskCoefficients;
    if (coefficients == null || coefficients.length != channels) return null;
    // Ngưỡng xác suất 0.5 tương đương logit 0, khỏi tính sigmoid.
    final logitThreshold = math.log(threshold / (1 - threshold));

    int px(double v) => (v * size).clamp(0, size).toInt();
    final x0 = px(d.left), x1 = math.max(px(d.right), x0 + 1);
    final y0 = px(d.top), y1 = math.max(px(d.bottom), y0 + 1);

    var count = 0;
    final rows = <int>{};
    final cols = <int>{};
    for (var y = y0; y < y1 && y < size; y++) {
      for (var x = x0; x < x1 && x < size; x++) {
        var logit = 0.0;
        for (var k = 0; k < channels; k++) {
          logit += coefficients[k] * at(k, y, x);
        }
        if (logit > logitThreshold) {
          count++;
          rows.add(y);
          cols.add(x);
        }
      }
    }
    final length =
        math.sqrt(rows.length * rows.length + cols.length * cols.length) / size;
    return d.withMask(area: count / (size * size), length: length);
  }
}
