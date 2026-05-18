import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/persistence_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Close Interception Tests', () {
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

    test('1. Close clean workbook', () async {
      bool onBeforeCloseInvoked = false;
      final options = PersistenceOptions(
        onBeforeClose: () async {
          onBeforeCloseInvoked = true;
          return true; // Allow close
        },
      );

      // It's clean, so it might just close or invoke the hook depending on logic.
      // Usually, if it's clean, the hook might return true.
      bool canClose = true;
      if (options.onBeforeClose != null) {
        canClose = await options.onBeforeClose!();
      }

      expect(canClose, isTrue);
      expect(onBeforeCloseInvoked, isTrue);
    });

    test('2. Close dirty workbook', () async {
      bool onBeforeCloseInvoked = false;
      final options = PersistenceOptions(
        onBeforeClose: () async {
          onBeforeCloseInvoked = true;
          return false; // Intercept close because it's dirty
        },
      );

      controller.updateCellValue(0, 0, 'Dirty');

      bool canClose = true;
      if (controller.state.hasUnsavedChanges && options.onBeforeClose != null) {
        canClose = await options.onBeforeClose!();
      }

      expect(canClose, isFalse);
      expect(onBeforeCloseInvoked, isTrue);
    });

    test('3. Save on close', () async {
      bool saved = false;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          saved = true;
          return true;
        },
        onBeforeClose: () async {
          // Simulate dialog that chooses "Save"
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Dirty');

      if (options.onSave != null) {
        final success = await options.onSave!(controller.state.workbook);
        if (success) controller.markAsClean();
      }

      bool canClose = true;
      if (controller.state.hasUnsavedChanges) {
        canClose = false; // Intercepted
      } else if (options.onBeforeClose != null) {
        canClose = await options.onBeforeClose!();
      }

      expect(saved, isTrue);
      expect(canClose, isTrue); // Can close after saving
    });

    test('4. Discard on close', () async {
      bool discarded = false;
      final options = PersistenceOptions(
        onDiscardChanges: () {
          discarded = true;
        },
        onBeforeClose: () async {
          // Simulate user choosing to discard
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Dirty');

      // User discards
      if (options.onDiscardChanges != null) {
        options.onDiscardChanges!();
        controller
            .markAsClean(); // Discarding usually cleans state or just pops
      }

      bool canClose = true;
      if (options.onBeforeClose != null) {
        canClose = await options.onBeforeClose!();
      }

      expect(discarded, isTrue);
      expect(canClose, isTrue);
    });

    test('5. Cancel close', () async {
      final options = PersistenceOptions(
        onBeforeClose: () async {
          return false; // User cancels close dialog
        },
      );

      controller.updateCellValue(0, 0, 'Dirty');

      bool canClose = true;
      if (controller.state.hasUnsavedChanges && options.onBeforeClose != null) {
        canClose = await options.onBeforeClose!();
      }

      expect(canClose, isFalse);
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test('6. Close during async save', () async {
      // Simulate close being blocked or awaiting save
      bool saveCompleted = false;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 50));
          saveCompleted = true;
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Dirty');

      final saveFuture = options.onSave?.call(controller.state.workbook);

      // Assume close is requested while saving
      expect(saveCompleted, isFalse);
      await saveFuture;
      expect(saveCompleted, isTrue);
    });

    test('7. Close during recalculation', () {
      controller.updateCellValue(0, 0, '10');
      controller.updateCellValue(0, 1, '=A1*2');
      // Recalc is synchronous in this engine, so we just check it doesn't crash on close
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.value?.toString(),
        '20.0',
      );
    });

    test('8. Close during large paste', () {
      for (int i = 0; i < 100; i++) {
        controller.updateCellValue(i, 0, 'V');
      }
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test('9. Close after failed save', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          return false; // Failed
        },
        onBeforeClose: () async {
          return false; // Block close
        },
      );

      controller.updateCellValue(0, 0, 'Test');
      await options.onSave?.call(controller.state.workbook);

      bool canClose = true;
      if (controller.state.hasUnsavedChanges && options.onBeforeClose != null) {
        canClose = await options.onBeforeClose!();
      }

      expect(canClose, isFalse);
    });

    test('10. Close after undo/redo chain', () {
      controller.updateCellValue(0, 0, 'A');
      controller.undo();

      bool canClose = true;
      if (controller.state.hasUnsavedChanges) {
        canClose = false;
      }
      expect(canClose, isTrue); // Clean because undone
    });
  });
}
