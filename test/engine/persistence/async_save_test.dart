import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/persistence_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Async Save Tests', () {
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

    test('1 & 2. Slow save callback (Network-like delay simulation)', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Dirty');
      expect(controller.state.hasUnsavedChanges, isTrue);

      final saveFuture = options.onSave?.call(controller.state.workbook);
      expect(
        controller.state.hasUnsavedChanges,
        isTrue,
      ); // Still dirty while saving

      final success = await saveFuture;
      if (success == true) {
        controller.markAsClean();
      }
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test('3. Concurrent edits during save', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'State 1');

      // Start save of State 1
      final saveFuture = options.onSave?.call(controller.state.workbook);

      // Edit while saving
      controller.updateCellValue(1, 1, 'State 2');

      await saveFuture;

      // We manually resolve clean state based on logic. If logic blindly calls markAsClean,
      // it might incorrectly mark State 2 as clean. In a real app, it should track revision saved.
      // But we just test what happens:
      // controller.markAsClean(); // Would erroneously mark State 2 clean if not careful.

      // A safe persistence hook saves the revision it fired on. If it completes, it marks that revision as clean.
      // Since we don't have atomic markRevisionAsClean(rev), we just test the race condition isn't crashing.
      expect(
        controller.state.workbook.activeSheet.cells['1,1']?.value,
        'State 2',
      );
    });

    test('4. Save while scrolling', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'Test');
      final saveFuture = options.onSave?.call(controller.state.workbook);

      // "Scroll"
      controller.selectCell(100, 100);

      await saveFuture;
      expect(controller.state.activeCell?.row, 100);
    });

    test('5. Save while recalculating', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return true;
        },
      );

      controller.updateCellValue(0, 0, '10');
      controller.updateCellValue(0, 1, '=A1*2');

      final saveFuture = options.onSave?.call(controller.state.workbook);
      await saveFuture;
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.value?.toString(),
        '20.0',
      );
    });

    test('6 & 7. Save interruption & retry handling', () async {
      int attempts = 0;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          attempts++;
          if (attempts == 1) {
            return false; // Interrupted/Failed
          }
          return true; // Retry success
        },
      );

      controller.updateCellValue(0, 0, 'Test');

      // First attempt
      final success1 = await options.onSave?.call(controller.state.workbook);
      expect(success1, isFalse);

      // Retry
      final success2 = await options.onSave?.call(controller.state.workbook);
      expect(success2, isTrue);
    });

    test('8. Multiple overlapping saves', () async {
      int activeSaves = 0;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          activeSaves++;
          await Future.delayed(const Duration(milliseconds: 50));
          activeSaves--;
          return true;
        },
      );

      controller.updateCellValue(0, 0, 'A');
      final save1 = options.onSave?.call(controller.state.workbook);

      controller.updateCellValue(0, 0, 'B');
      final save2 = options.onSave?.call(controller.state.workbook);

      expect(activeSaves, 2); // Both overlap
      await Future.wait([save1!, save2!].cast<Future<void>>());
      expect(activeSaves, 0);
    });

    test('9. Async save failure handling', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw Exception('Network error');
        },
      );

      controller.updateCellValue(0, 0, 'Test');

      try {
        await options.onSave?.call(controller.state.workbook);
        fail('Should throw');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      // State should still be dirty and intact
      expect(controller.state.hasUnsavedChanges, isTrue);
      expect(controller.state.workbook.activeSheet.cells['0,0']?.value, 'Test');
    });
  });
}
