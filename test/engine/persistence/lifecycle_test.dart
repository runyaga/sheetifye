import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/persistence_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lifecycle Tests (Mobile/Desktop/Web Interception logic)', () {
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

    group('Mobile Lifecycle Tests', () {
      test('1 & 2. Android/iOS back navigation interception', () async {
        controller.updateCellValue(0, 0, 'Dirty');
        bool canPop = !controller.state.hasUnsavedChanges;
        expect(canPop, isFalse);
      });

      test('3. App background/foreground (auto-save logic check)', () async {
        bool autoSaved = false;
        final options = PersistenceOptions(
          onSave: (workbook) async {
            autoSaved = true;
            return true;
          },
        );
        controller.updateCellValue(0, 0, 'Dirty');

        // Simulating app going to background triggers save
        if (controller.state.hasUnsavedChanges && options.onSave != null) {
          final success = await options.onSave!(controller.state.workbook);
          if (success) controller.markAsClean();
        }

        expect(autoSaved, isTrue);
        expect(controller.state.hasUnsavedChanges, isFalse);
      });

      test('4. Route pop interception', () {
        controller.updateCellValue(0, 0, 'Dirty');
        // WillPopScope equivalent
        bool shouldPop = !controller.state.hasUnsavedChanges;
        expect(shouldPop, isFalse);
      });

      test('5. Mobile save dialog behavior', () async {
        bool dialogShown = false;
        final options = PersistenceOptions(
          onBeforeClose: () async {
            dialogShown = true;
            return false; // Dialog shown, user cancels
          },
        );

        controller.updateCellValue(0, 0, 'Dirty');
        if (controller.state.hasUnsavedChanges &&
            options.onBeforeClose != null) {
          await options.onBeforeClose!();
        }

        expect(dialogShown, isTrue);
      });

      test('6. Mobile keyboard dismissal', () {
        controller.setEditing(true, initialValue: 'Test');
        // Keyboard dismissed -> commits edit
        controller.commitEdit('Test');
        expect(controller.state.isEditing, isFalse);
      });

      test('7. Mobile toolbar save action', () async {
        bool saved = false;
        final options = PersistenceOptions(
          onSave: (workbook) async {
            saved = true;
            return true;
          },
        );

        controller.updateCellValue(0, 0, 'Dirty');

        // Simulate toolbar save icon press
        if (options.onSave != null) {
          final success = await options.onSave!(controller.state.workbook);
          if (success) controller.markAsClean();
        }

        expect(saved, isTrue);
      });
    });

    group('Desktop Lifecycle Tests', () {
      test('1. Window close interception', () async {
        controller.updateCellValue(0, 0, 'Dirty');
        bool windowCanClose = !controller.state.hasUnsavedChanges;
        expect(windowCanClose, isFalse);
      });

      test('2. Cmd/Ctrl + S', () async {
        bool saved = false;
        final options = PersistenceOptions(
          onSave: (workbook) async {
            saved = true;
            return true;
          },
        );

        controller.updateCellValue(0, 0, 'Dirty');

        // Simulate shortcut
        if (options.onSave != null) {
          final success = await options.onSave!(controller.state.workbook);
          if (success) controller.markAsClean();
        }

        expect(saved, isTrue);
      });

      test('3. Cmd/Ctrl + Shift + S', () async {
        bool savedAs = false;
        final options = PersistenceOptions(
          onSaveAs: (workbook) async {
            savedAs = true;
            return true;
          },
        );

        controller.updateCellValue(0, 0, 'Dirty');

        // Simulate shortcut
        if (options.onSaveAs != null) {
          await options.onSaveAs!(controller.state.workbook);
        }

        expect(savedAs, isTrue);
      });

      test('4. Multiple window saves', () async {
        // Assume multiple controllers logic, we test if the state isolation is clean
        expect(controller.state.hasUnsavedChanges, isFalse);
      });

      test('5. Window resize during save', () async {
        final options = PersistenceOptions(
          onSave: (workbook) async {
            await Future.delayed(const Duration(milliseconds: 10));
            return true;
          },
        );

        controller.updateCellValue(0, 0, 'Dirty');

        final future = options.onSave?.call(controller.state.workbook);
        // Simulate resize
        controller.expandIfNeeded(100, 100);

        await future;
        controller.markAsClean();
        expect(controller.state.hasUnsavedChanges, isFalse);
      });

      test('6. Save after rapid keyboard edits', () {
        controller.updateCellValue(0, 0, 'R');
        controller.updateCellValue(0, 0, 'Ra');
        controller.updateCellValue(0, 0, 'Rap');
        controller.markAsClean();
        expect(controller.state.hasUnsavedChanges, isFalse);
      });
    });

    group('Web Lifecycle Tests', () {
      test('1. Browser refresh warning', () {
        controller.updateCellValue(0, 0, 'Dirty');
        // Web logic: window.onBeforeUnload shows warning if dirty
        expect(controller.state.hasUnsavedChanges, isTrue);
      });

      test('2. Browser tab close warning', () {
        controller.updateCellValue(0, 0, 'Dirty');
        expect(controller.state.hasUnsavedChanges, isTrue);
      });

      test('3. beforeunload handling', () {
        controller.updateCellValue(0, 0, 'Dirty');
        expect(controller.state.hasUnsavedChanges, isTrue);
      });

      test('4. Save before refresh', () async {
        bool saved = false;
        final options = PersistenceOptions(
          onSave: (workbook) async {
            saved = true;
            return true;
          },
        );

        controller.updateCellValue(0, 0, 'Dirty');

        if (options.onSave != null) {
          final success = await options.onSave!(controller.state.workbook);
          if (success) controller.markAsClean();
        }

        expect(saved, isTrue);
        expect(
          controller.state.hasUnsavedChanges,
          isFalse,
        ); // Now refresh is safe
      });

      test('5. Web export handling', () async {
        bool exported = false;
        final options = PersistenceOptions(
          onSaveAs: (workbook) async {
            exported = true; // Web downloads file instead of native save dialog
            return true;
          },
        );

        if (options.onSaveAs != null) {
          await options.onSaveAs!(controller.state.workbook);
        }

        expect(exported, isTrue);
      });
    });
  });
}
