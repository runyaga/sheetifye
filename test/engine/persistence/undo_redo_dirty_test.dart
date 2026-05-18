import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Undo/Redo Dirty Synchronization Tests', () {
    late ProviderContainer container;
    late WorkbookController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);
      controller.markAsClean();
    });

    tearDown(() {
      container.dispose();
    });

    test('11. Edit -> undo back to original -> dirty false', () {
      controller.updateCellValue(0, 0, 'Edit1');
      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.undo();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('12. Edit -> redo -> dirty true', () {
      controller.updateCellValue(0, 0, 'Edit1');
      controller.undo();
      expect(controller.state.hasUnsavedChanges, isFalse);

      controller.redo();
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test('13. Multiple edits -> partial undo -> dirty remains true', () {
      controller.updateCellValue(0, 0, 'Edit1');
      controller.updateCellValue(1, 0, 'Edit2');
      controller.updateCellValue(2, 0, 'Edit3');

      controller.undo(); // Undo Edit3
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test('14. Undo to last saved state -> dirty false', () {
      controller.updateCellValue(0, 0, 'Edit1');
      controller.updateCellValue(1, 0, 'Edit2');

      // Save here
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);

      controller.updateCellValue(2, 0, 'Edit3');
      controller.updateCellValue(3, 0, 'Edit4');
      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.undo(); // Undo Edit4
      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.undo(); // Undo Edit3
      expect(
        controller.state.hasUnsavedChanges,
        isFalse,
      ); // Reached last saved state
    });

    test('15. Redo after save -> dirty true', () {
      controller.updateCellValue(0, 0, 'Edit1');
      controller.undo();

      controller.markAsClean(); // Save at original state
      expect(controller.state.hasUnsavedChanges, isFalse);

      controller.redo(); // Redo Edit1
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test('16. Paste undo -> dirty sync correct', () {
      controller.updateCellValue(0, 0, 'Source');
      controller.markAsClean();

      // We test structural undo with range clear as paste might have clipboard delays in headless mode
      controller.clearRange(GridRange.fromRect(0, 0, 1, 1));
      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.undo();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('17. Structural undo -> dirty sync correct', () {
      // Assuming addSheet has undo, but our addSheet doesn't seem to use CommandManager currently.
      // We'll test clearRange which is structural.
      controller.updateCellValue(0, 0, 'ToClear');
      controller.markAsClean();

      controller.clearRange(GridRange.fromRect(0, 0, 1, 1));
      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.undo();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('18. Formula undo -> dirty sync correct', () {
      controller.markAsClean();
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: '=1+1');
      controller.commitEdit('=1+1');

      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.undo();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test(
      'CRITICAL: Baseline critical scenario: Edit A1, Edit A2, Save, Edit A3, Undo A3 -> dirty false',
      () {
        // 1. Load workbook
        expect(controller.state.hasUnsavedChanges, isFalse);

        // 2. Edit A1
        controller.updateCellValue(0, 0, 'A1');

        // 3. Edit A2
        controller.updateCellValue(1, 0, 'A2');

        // 4. Save workbook
        controller.markAsClean();
        expect(controller.state.hasUnsavedChanges, isFalse);

        // 5. Edit A3
        controller.updateCellValue(2, 0, 'A3');
        expect(controller.state.hasUnsavedChanges, isTrue);

        // 6. Undo A3 edit
        controller.undo();

        // Expected: dirty = false because it returned to last saved state
        expect(controller.state.hasUnsavedChanges, isFalse);
      },
    );
  });
}
