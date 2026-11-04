/// Dữ liệu minh họa theo thiết kế Figma.
///
/// Chỉ còn các số tổng hợp cho Tổng quan và Báo cáo (sẽ thay bằng số liệu thật
/// ở Card 22). Danh mục tài sản đã dùng dữ liệu thật (Isar + Supabase).
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
  static const notAudited = 384;
  static const damaged = 8;
  static const discrepancies = 15;

  static const areas = [
    DemoArea('Kho trung tâm', 340, 400, 3),
    DemoArea('Xưởng sản xuất A', 288, 360, 5),
    DemoArea('Trạm kỹ thuật', 156, 240, 2),
    DemoArea('Kho vật tư B', 80, 248, 5),
  ];
}
