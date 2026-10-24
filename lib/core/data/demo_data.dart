import '../widgets/fieldline_widgets.dart';

/// Dữ liệu minh họa theo thiết kế Figma.
///
/// Ứng dụng chưa có danh mục tài sản và kế hoạch kiểm kê thật, nên các con số
/// tổng hợp dưới đây chỉ để trình bày. Phiếu kiểm kê, hàng đợi đồng bộ và
/// xuất PDF dùng dữ liệu Isar thật.
class DemoAsset {
  const DemoAsset({
    required this.name,
    required this.code,
    required this.area,
    required this.quantity,
    required this.status,
    required this.tone,
    required this.lastAudit,
    required this.category,
  });

  final String name;
  final String code;
  final String area;
  final int quantity;
  final String status;
  final FlTone tone;
  final String lastAudit;
  final String category;
}

class DemoArea {
  const DemoArea(this.name, this.done, this.planned, this.discrepancy);

  final String name;
  final int done;
  final int planned;
  final int discrepancy;

  double get progress => done / planned;
}

abstract final class DemoData {
  static const totalAssets = 1248;
  static const auditedAssets = 864;
  static const needsCheck = 23;
  static const goodAssets = 1102;
  static const needsCheckAll = 123;
  static const retired = 23;
  static const notAudited = 384;
  static const damaged = 8;
  static const discrepancies = 15;

  static const assets = [
    DemoAsset(
      name: 'Máy bơm ly tâm Ebara',
      code: 'TS-BOM-0248',
      area: 'Kho trung tâm',
      quantity: 12,
      status: 'Hoạt động tốt',
      tone: FlTone.success,
      lastAudit: '22/10/2026',
      category: 'Thiết bị bơm',
    ),
    DemoAsset(
      name: 'Động cơ điện Siemens',
      code: 'TS-DC-0142',
      area: 'Xưởng sản xuất A',
      quantity: 8,
      status: 'Cần kiểm tra',
      tone: FlTone.warning,
      lastAudit: '22/10/2026',
      category: 'Thiết bị truyền động',
    ),
    DemoAsset(
      name: 'Tủ điện phân phối',
      code: 'TS-TD-0086',
      area: 'Trạm kỹ thuật',
      quantity: 4,
      status: 'Hoạt động tốt',
      tone: FlTone.success,
      lastAudit: '21/10/2026',
      category: 'Thiết bị điện',
    ),
    DemoAsset(
      name: 'Máy khoan Bosch GSB',
      code: 'TS-MK-0321',
      area: 'Kho vật tư B',
      quantity: 24,
      status: 'Hoạt động tốt',
      tone: FlTone.success,
      lastAudit: '21/10/2026',
      category: 'Dụng cụ cầm tay',
    ),
    DemoAsset(
      name: 'Van công nghiệp DN100',
      code: 'TS-VAN-0175',
      area: 'Kho trung tâm',
      quantity: 36,
      status: 'Hư hỏng',
      tone: FlTone.danger,
      lastAudit: '20/10/2026',
      category: 'Van & đường ống',
    ),
  ];

  static const areas = [
    DemoArea('Kho trung tâm', 340, 400, 3),
    DemoArea('Xưởng sản xuất A', 288, 360, 5),
    DemoArea('Trạm kỹ thuật', 156, 240, 2),
    DemoArea('Kho vật tư B', 80, 248, 5),
  ];
}
