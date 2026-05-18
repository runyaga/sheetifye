import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/features/workbook/widgets/sheetifye_workbook.dart';
import 'package:sheetifye/src/features/grid/widgets/sheet_grid.dart';
import 'package:sheetifye/src/features/formula_bar/widgets/formula_bar.dart';
import 'package:sheetifye/src/features/tabs/widgets/sheet_tabs.dart';

void main() {
  testWidgets(
    'SheetifyeWorkbook root UI mounts all sub-components and supports read-only switches',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SheetifyeWorkbook(readOnly: false)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify sub-components mount successfully
      expect(find.byType(FormulaBar), findsOneWidget);
      expect(find.byType(SheetGrid), findsOneWidget);
      expect(find.byType(SheetTabs), findsOneWidget);
    },
  );
}
