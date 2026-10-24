import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import 'package:field_inventory_edge_ai/core/network/connectivity_provider.dart';
import 'package:field_inventory_edge_ai/core/widgets/fieldline_widgets.dart';
import 'package:field_inventory_edge_ai/features/offline_audit/data/repositories/isar_audit_repository_impl.dart';
import 'package:field_inventory_edge_ai/features/offline_audit/presentation/controllers/sync_controller.dart';

/// Kích hoạt đồng bộ dữ liệu ngoại tuyến lên Supabase Cloud.
Future<void> triggerSync(BuildContext context, WidgetRef ref) async {
  final syncState = ref.read(syncControllerProvider);
  if (syncState.isLoading) return;

  // Không thử gọi Supabase khi thiết bị không có mạng; phiếu vẫn nằm trên máy.
  if (ref.read(isOnlineProvider).value == false) {
    showFlSnack(
      context,
      'Thiết bị đang ngoại tuyến. Phiếu vẫn được lưu trên máy và sẽ đồng bộ khi có mạng.',
      tone: FlTone.warning,
    );
    return;
  }

  try {
    final count = await ref.read(syncControllerProvider.notifier).syncAll();
    if (context.mounted) {
      showFlSnack(
        context,
        count == 0
            ? 'Không có phiếu nào cần đồng bộ.'
            : 'Đã đồng bộ $count phiếu lên đám mây.',
        tone: FlTone.success,
      );
    }
  } catch (e) {
    if (context.mounted) {
      showFlSnack(
        context,
        'Chưa đồng bộ được: $e. Dữ liệu vẫn an toàn trên máy.',
        tone: FlTone.danger,
      );
    }
  }
}

/// Xuất báo cáo PDF và mở hộp thoại chia sẻ hệ thống.
Future<void> exportPdfReport(BuildContext context, WidgetRef ref) async {
  try {
    showFlSnack(context, 'Đang tạo báo cáo PDF...');

    final repository = ref.read(auditRepositoryProvider);
    final bytes = await repository.exportPdfReport();

    await Printing.sharePdf(bytes: bytes, filename: 'bao_cao_kiem_ke.pdf');
  } catch (e) {
    if (context.mounted) {
      showFlSnack(context, 'Lỗi khi xuất PDF: $e', tone: FlTone.danger);
    }
  }
}
