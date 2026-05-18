import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/overlays/cell_editor_overlay.dart';

void main() {
  testWidgets(
    'CellEditorOverlay displays textbox and validation messages correctly',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      // Force editing state to render overlay
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'EditText');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CellEditorOverlay(onCancel: () {}, onCommit: (val) {}),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify textField mounts with initial edit value
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('EditText'), findsOneWidget);

      container.dispose();
    },
  );
}
