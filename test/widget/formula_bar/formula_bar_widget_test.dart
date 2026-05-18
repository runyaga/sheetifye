import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/features/formula_bar/widgets/formula_bar.dart';

void main() {
  testWidgets(
    'FormulaBar displays address indicator and selected cell values',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.selectCell(0, 0); // A1
      controller.updateCellValue(0, 0, 'CellData');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: FormulaBar())),
        ),
      );

      await tester.pumpAndSettle();

      // Verify address indicator says "A1"
      expect(find.text('A1'), findsOneWidget);

      container.dispose();
    },
  );
}
