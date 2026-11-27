import 'entities/detection.dart';

/// Giải mã đầu ra YOLO dạng [4 + số lớp (+ hệ số mask)][số ô] thành danh sách
/// vùng phát hiện.
///
/// - Mỗi ô lấy lớp có điểm cao nhất; bỏ ô dưới ngưỡng của lớp đó.
/// - Lọc trùng (NMS) theo từng lớp với ngưỡng IoU [iouThreshold].
/// - Toạ độ đầu ra chuẩn hoá 0..1. Một số bản xuất TFLite trả toạ độ theo
///   pixel (0..[inputSize]); khi đó tự chia cho [inputSize].
/// - Model phân vùng (YOLOv8-seg) có thêm [maskChannels] hàng hệ số mask sau
///   các hàng điểm lớp; hệ số được gắn vào [Detection.maskCoefficients].
List<Detection> decodeYoloBoxes(
  List<List<double>> output,
  List<String> labels, {
  required double Function(int classIndex) thresholdFor,
  int inputSize = 640,
  double iouThreshold = 0.45,
  int maxDetections = 30,
  bool Function(int classIndex)? keepClass,
  int maskChannels = 0,
}) {
  final classCount = labels.length;
  if (output.length < 4 + classCount + maskChannels || classCount == 0) {
    return const [];
  }
  final anchors = output[0].length;

  var scale = 1.0;
  for (var c = 0; c < 4 && scale == 1.0; c++) {
    for (final v in output[c]) {
      if (v > 2) {
        scale = 1 / inputSize;
        break;
      }
    }
  }

  final candidates = <(Detection, int)>[];
  for (var a = 0; a < anchors; a++) {
    var best = -1;
    var bestScore = 0.0;
    for (var c = 0; c < classCount; c++) {
      final s = output[4 + c][a];
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    if (best < 0 || bestScore < thresholdFor(best)) continue;
    if (keepClass != null && !keepClass(best)) continue;
    final w = output[2][a] * scale;
    final h = output[3][a] * scale;
    if (w <= 0 || h <= 0) continue;
    candidates.add((
      Detection(
        classIndex: best,
        label: labels[best],
        score: bestScore,
        cx: output[0][a] * scale,
        cy: output[1][a] * scale,
        w: w,
        h: h,
      ),
      a,
    ));
  }

  candidates.sort((a, b) => b.$1.score.compareTo(a.$1.score));
  final kept = <Detection>[];
  final firstMask = 4 + classCount;
  for (final (d, anchor) in candidates) {
    final duplicate = kept.any(
      (k) => k.classIndex == d.classIndex && k.iou(d) > iouThreshold,
    );
    if (duplicate) continue;
    final coefficients = maskChannels == 0
        ? null
        : List<double>.unmodifiable([
            for (var k = 0; k < maskChannels; k++)
              output[firstMask + k][anchor],
          ]);
    kept.add(_clip(d, coefficients));
    if (kept.length >= maxDetections) break;
  }
  return kept;
}

/// Cắt khung về trong ô ảnh (YOLO có thể trả khung tràn mép).
Detection _clip(Detection d, List<double>? coefficients) {
  double c(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
  final l = c(d.left), t = c(d.top), r = c(d.right), b = c(d.bottom);
  return Detection(
    classIndex: d.classIndex,
    label: d.label,
    score: d.score,
    cx: (l + r) / 2,
    cy: (t + b) / 2,
    w: r - l,
    h: b - t,
    maskCoefficients: coefficients,
  );
}
