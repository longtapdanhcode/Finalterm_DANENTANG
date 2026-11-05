import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

import '../../features/asset_catalog/data/models/asset_model.dart';
import '../../features/asset_catalog/domain/entities/asset_status.dart';
import '../../features/offline_audit/data/models/audit_record_model.dart';
import '../../features/offline_audit/domain/entities/audit_condition.dart';

/// Tiện ích hỗ trợ tạo tệp PDF báo cáo kiểm kê hiện trường.
class PdfReportGenerator {
  const PdfReportGenerator._();

  /// Font Inter đóng gói trong app (có đủ dấu tiếng Việt, không cần mạng).
  /// Chỉ khi không đọc được asset mới dùng Helvetica (không có dấu).
  static Future<(pw.Font, pw.Font)> _loadFonts() async {
    try {
      final regular = await rootBundle.load(
        'assets/fonts/inter/Inter-Regular.ttf',
      );
      final bold = await rootBundle.load('assets/fonts/inter/Inter-Bold.ttf');
      return (pw.Font.ttf(regular), pw.Font.ttf(bold));
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  /// Tạo PDF "Danh sách tài sản" từ [assets] (thường là danh sách đang lọc).
  static Future<Uint8List> generateAssetList(List<AssetModel> assets) async {
    final pdf = pw.Document();
    final (font, boldFont) = await _loadFonts();
    final date = DateFormat('dd/MM/yyyy');
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalQuantity = assets.fold<int>(0, (sum, a) => sum + a.quantity);

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'DANH SÁCH TÀI SẢN',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                    color: PdfColors.teal800,
                  ),
                ),
                pw.Text(
                  'Ngày xuất: $generatedAt',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${assets.length} tài sản • Tổng số lượng: $totalQuantity',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.teal800),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Trang ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          if (assets.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 40),
              child: pw.Center(
                child: pw.Text(
                  'Không có tài sản nào trong danh sách.',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'STT',
                'Mã tài sản',
                'Tên tài sản',
                'Khu vực',
                'SL',
                'Tình trạng',
                'Kiểm kê gần nhất',
              ],
              data: [
                for (final (i, a) in assets.indexed)
                  [
                    '${i + 1}',
                    a.code,
                    a.name,
                    [a.area, a.location].whereType<String>().join(' • '),
                    '${a.quantity}',
                    AssetStatus.fromCode(a.status).label,
                    a.lastAuditAt == null
                        ? 'Chưa kiểm kê'
                        : date.format(a.lastAuditAt!),
                  ],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignments: {0: pw.Alignment.center, 4: pw.Alignment.center},
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Tạo mảng byte PDF từ danh sách các bản ghi [AuditRecordModel].
  static Future<Uint8List> generateAuditReport(
    List<AuditRecordModel> records,
  ) async {
    final pdf = pw.Document();

    final (font, boldFont) = await _loadFonts();

    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final generatedAt = dateFormat.format(DateTime.now());

    // Tính tổng số lượng thiết bị đã kiểm kê
    final totalQuantity = records.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BÁO CÁO KIỂM KÊ HIỆN TRƯỜNG',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 18,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Hệ thống Field Inventory Edge AI (Offline-First)',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Ngày xuất: $generatedAt',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Tổng mục: ${records.length}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Báo cáo tự động từ Field Inventory Edge AI App',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Trang ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        build: (context) {
          final headers = [
            'STT',
            'Mã thiết bị',
            'Tài sản',
            'Khu vực',
            'Tình trạng',
            'Số lượng',
            'Thời gian',
          ];

          final data = List.generate(records.length, (index) {
            final record = records[index];
            final area = [
              record.area,
              record.location,
            ].whereType<String>().join(' • ');
            final timeStr = record.timestamp != null
                ? dateFormat.format(record.timestamp!)
                : '-';

            return [
              '${index + 1}',
              record.scanCode ?? '-',
              _assetCell(record),
              area.isEmpty ? '-' : area,
              AuditCondition.fromCode(record.condition)?.label ?? '-',
              '${record.quantity}',
              timeStr,
            ];
          });

          return [
            if (records.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 40),
                  child: pw.Text(
                    'Chưa có dữ liệu kiểm kê nào được ghi nhận.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              )
            else ...[
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                ),
                cellStyle: pw.TextStyle(font: font, fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                },
                headerAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
              ),
              if (records.any((r) => r.signerName != null)) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  'Người ký xác nhận',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                for (final (index, record) in records.indexed)
                  if (record.signerName != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '${index + 1}. ${record.scanCode ?? '-'}: ${record.signerName}'
                        '${record.signerRole != null ? ' (${record.signerRole})' : ''}',
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                    ),
              ],
              if (records.any((r) => r.notes != null)) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  'Ghi chú hiện trường',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                for (final (index, record) in records.indexed)
                  if (record.notes != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '${index + 1}. ${record.scanCode ?? '-'}: ${record.notes}',
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                    ),
              ],
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 0.5,
                      ),
                    ),
                    child: pw.Text(
                      'TỔNG SỐ LƯỢNG THIẾT BỊ: $totalQuantity',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Tên tài sản, kèm nhãn AI khi khác tên do kiểm kê viên nhập.
  static String _assetCell(AuditRecordModel record) {
    final name = record.assetName;
    final ai = record.aiDetectedLabel;
    if (name == null) return ai ?? 'Chưa nhận diện';
    if (ai == null || ai == name) return name;
    return '$name\n(AI: $ai)';
  }
}
