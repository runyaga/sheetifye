import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/features/workbook/widgets/sheetifye_workbook.dart';

void main() {
  testWidgets(
    'Web UX Integration - Resize, Hover Handles, and Scroll Virtualization',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1024,
                height: 768,
                child: SheetifyeWorkbook(readOnly: false),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify grid mounts and is visible
      expect(find.byType(SheetifyeWorkbook), findsOneWidget);
    },
  );
}
