import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:field_inventory_edge_ai/core/widgets/fieldline_widgets.dart';
import 'package:field_inventory_edge_ai/features/canvas_signature/presentation/screens/signature_screen.dart';

/// Kích thước khung web 1440×1000 của Figma (bố cục desktop).
void useDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('SignatureScreen Widget Tests', () {
    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: SignatureScreen(
            summary: AuditSummary(
              scanCode: 'TS-DC-0142',
              label: 'Động cơ điện',
              name: '',
              area: 'Xưởng sản xuất A',
              quantity: 8,
              condition: 'Hoạt động tốt',
              conditionTone: FlTone.success,
              createdAt: DateTime(2026, 10, 22, 9, 44),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders Signature canvas, action buttons, and title', (
      tester,
    ) async {
      useDesktopView(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Ký xác nhận kiểm kê'), findsOneWidget);
      expect(find.text('Chạm và kéo để ký'), findsOneWidget);
      expect(find.text('TS-DC-0142'), findsOneWidget);
      expect(find.byType(Signature), findsOneWidget);
      expect(find.text('Xóa và ký lại'), findsOneWidget);
      expect(find.text('Hoàn tất & lưu phiếu kiểm kê'), findsOneWidget);
    });

    testWidgets('Shows warning snackbar when confirming with empty canvas', (
      tester,
    ) async {
      useDesktopView(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap confirm on empty canvas
      final confirm = find.text('Hoàn tất & lưu phiếu kiểm kê');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng ký tên trước khi hoàn tất!'), findsOneWidget);
    });

    testWidgets('Clear button is clickable and resets canvas', (tester) async {
      useDesktopView(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final clearFinder = find.text('Xóa và ký lại');
      expect(clearFinder, findsOneWidget);
      await tester.ensureVisible(clearFinder);

      await tester.tap(clearFinder);
      await tester.pumpAndSettle();

      expect(find.byType(Signature), findsOneWidget);
    });
  });
}
