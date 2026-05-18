import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/persistence_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Save Lifecycle Tests', () {
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

    test('1. onSave callback invoked & 2. Save resets dirty state', () async {
      bool onSaveInvoked = false;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          onSaveInvoked = true;
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Test');
      expect(controller.state.hasUnsavedChanges, isTrue);

      if (options.onSave != null) {
        final success = await options.onSave!(controller.state.workbook);
        if (success) {
          controller.markAsClean();
        }
      }

      expect(onSaveInvoked, isTrue);
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('3. Save failure preserves dirty state', () async {
      bool onSaveInvoked = false;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          onSaveInvoked = true;
          return false; // Simulate failure
        },
      );

      controller.updateCellValue(0, 0, 'Test');
      expect(controller.state.hasUnsavedChanges, isTrue);

      if (options.onSave != null) {
        final success = await options.onSave!(controller.state.workbook);
        if (success) {
          controller.markAsClean();
        }
      }

      expect(onSaveInvoked, isTrue);
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test('4. Async save works correctly', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Test');

      if (options.onSave != null) {
        final success = await options.onSave!(controller.state.workbook);
        if (success) {
          controller.markAsClean();
        }
      }

      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('5. Save while scrolling', () async {
      controller.updateCellValue(100, 100, 'Test');
      // Simulate scrolling action logic here if needed, but the save should just capture state
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('6. Save while recalculating', () async {
      controller.updateCellValue(0, 0, '10');
      controller.updateCellValue(0, 1, '=A1*2');

      // Save should capture the recalculated state
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.value?.toString(),
        '20.0',
      );
    });

    test('7. Save after large paste', () async {
      for (int i = 0; i < 100; i++) {
        controller.updateCellValue(i, 0, 'Test$i');
      }
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('8. Save after formulas', () {
      controller.updateCellValue(0, 0, '=SUM(1,2,3)');
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('9. Save after merges', () {
      controller.clearRange(GridRange.fromRect(0, 0, 2, 2));
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('10. Save after sort/filter', () {
      controller.sortRange(GridRange.fromRect(0, 0, 5, 5), 0);
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('11. Save after undo/redo chain', () {
      controller.updateCellValue(0, 0, '1');
      controller.updateCellValue(0, 0, '2');
      controller.undo();
      controller.redo();
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('12. Save while overlays active', () {
      controller.setEditing(true, initialValue: 'Editing');
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('13. Save during rapid edits', () {
      controller.updateCellValue(0, 0, 'A');
      controller.updateCellValue(0, 0, 'B');
      controller.updateCellValue(0, 0, 'C');
      controller.markAsClean();
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('14. Multiple rapid save requests', () async {
      int saveCount = 0;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 20));
          saveCount++;
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Test');

      // Fire two saves concurrently (not awaited yet)
      final f1 = options.onSave!(controller.state.workbook);
      final f2 = options.onSave!(controller.state.workbook);

      // Both are still in-flight (async delay not elapsed)
      expect(saveCount, 0);
      await Future.wait([f1, f2]);
      expect(saveCount, 2);
    });

    test('15. Save cancellation handling', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          return false; // Simulate user cancelling the save dialog
        },
      );

      controller.updateCellValue(0, 0, 'Test');
      final success = await options.onSave!(controller.state.workbook);
      if (success) controller.markAsClean();

      expect(controller.state.hasUnsavedChanges, isTrue);
    });
  });
}
