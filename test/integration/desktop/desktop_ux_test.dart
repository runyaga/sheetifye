import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  testWidgets(
    'Desktop UX Integration - Arrow Navigation, Shortcuts, and Direct Edits',
    (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SheetifyeWorkbook(readOnly: false)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final controller = container.read(workbookProvider.notifier);

      // Select cell
      controller.selectCell(0, 0);
      expect(controller.state.activeCell?.row, 0);

      // Simulate arrow down navigation via controller
      controller.moveActiveCell(1, 0);
      expect(controller.state.activeCell?.row, 1);

      // Direct typing simulation
      controller.setEditing(true, initialValue: 'D');
      expect(controller.state.isEditing, isTrue);

      container.dispose();
    },
  );
}
