import 'package:field_inventory_edge_ai/features/damage_assessment/domain/entities/damage_enums.dart';

class AiConfig {
  const AiConfig._();

  /// Mô hình phân vùng YOLOv8n-seg 4 lớp hư hỏng bề mặt (best-newdomain.pt)
  /// đã xuất sang TFLite. Đầu vào 1x3x640x640 (NCHW, RGB 0..1). Hai đầu ra:
  /// - 1x40x8400: cx, cy, w, h (chuẩn hoá 0..1), điểm 4 lớp, 32 hệ số mask;
  /// - 1x32x160x160: proto mask cho cả ô ảnh vào.
  /// Model phát hiện cũ (chỉ một đầu ra 1x(4+số lớp)x8400) vẫn chạy được.
  static const String modelPath = 'assets/models/object_detection.tflite';

  /// Nhãn hiển thị, đúng thứ tự lớp lúc huấn luyện:
  /// vet_nut, tham_moc, bong_son, gi_set.
  static const String labelPath = 'assets/models/labels.txt';

  /// Kích thước cạnh đầu vào của mô hình.
  static const int inputSize = 640;

  /// Tỉ lệ cạnh khung xanh so với cạnh ngắn của ảnh camera. Màn Quét hiển thị
  /// camera kiểu cover nên khung xanh (~254pt trên khung xem ~366pt) chiếm
  /// khoảng 70% chiều ngang ảnh. AI chỉ nhận phần ảnh giữa này, bỏ chữ/giao
  /// diện xung quanh và bớt phải thu nhỏ ảnh.
  static const double cropFraction = 0.7;

  /// Ngưỡng tin cậy chung cho cả 4 lớp hư hỏng. Model hiện tại (mAP50 mask
  /// 0.40, recall 0.37 trên tập val) cho điểm thấp hơn model cũ nên ngưỡng
  /// hạ xuống 0.4; người kiểm kê vẫn xác nhận và sửa số đo trên phiếu.
  static const double confidenceThreshold = 0.4;

  /// Lớp của model ứng với loại hư hỏng bề mặt nào (thứ tự trong
  /// docs/ai-training/HUONG_DAN_TRAIN_MODEL_BE_MAT.md).
  static const Map<int, DamageType> damageTypeByClass = {
    0: DamageType.crack,
    1: DamageType.waterMold,
    2: DamageType.peelingPaint,
    3: DamageType.rust,
  };

  /// Ngưỡng IoU khi lọc các khung trùng nhau của cùng một lớp.
  static const double nmsIouThreshold = 0.45;

  /// Số khung tối đa giữ lại cho một khung hình.
  static const int maxDetections = 30;

  /// Cạnh thật (cm) của thẻ QR dán trên bề mặt, dùng để quy đổi pixel ra cm.
  static const double markerSizeCm = 10;
}
