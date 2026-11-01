import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import 'package:field_inventory_edge_ai/core/database/local_db_init.dart';
import 'package:field_inventory_edge_ai/features/offline_audit/data/models/audit_record_model.dart';

/// Danh sách bản ghi kiểm kê trên máy, tự cập nhật mỗi khi Isar thay đổi.
///
/// Sắp xếp mới nhất lên đầu để dùng trực tiếp cho các danh sách "gần đây".
final auditRecordsProvider = StreamProvider<List<AuditRecordModel>>((ref) {
  final isar = ref.watch(isarInstanceProvider);
  return isar.auditRecordModels.watchLazy(fireImmediately: true).map((_) {
    final records = isar.auditRecordModels.where().findAll();
    records.sort(
      (a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
    return records;
  });
});

/// Số bản ghi chưa đồng bộ lên Supabase.
final pendingSyncCountProvider = Provider<int>((ref) {
  final records = ref.watch(auditRecordsProvider).value ?? const [];
  return records.where((r) => !r.isSynced).length;
});
