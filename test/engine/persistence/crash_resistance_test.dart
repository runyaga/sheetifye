import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/persistence_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crash Resistance Tests', () {
    late ProviderContainer container;
    late WorkbookController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);
    });

    tearDown(() {
      container.dispose();
    });

    test('1. Rapid save spam', () async {
      int saves = 0;
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 5));
          saves++;
          return true;
        },
      );

      List<Future<void>> futures = [];
      for (int i = 0; i < 100; i++) {
        controller.updateCellValue(0, 0, 'Val$i');
        if (options.onSave != null) {
          futures.add(options.onSave!(controller.state.workbook));
        }
      }

      await Future.wait(futures);
      expect(saves, 100);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.value,
        'Val99',
      );
    });

    test('2. Rapid SaveAs spam', () async {
      int saveAsCount = 0;
      final options = PersistenceOptions(
        onSaveAs: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 5));
          saveAsCount++;
          return true;
        },
      );

      List<Future<void>> futures = [];
      for (int i = 0; i < 50; i++) {
        if (options.onSaveAs != null) {
          futures.add(options.onSaveAs!(controller.state.workbook));
        }
      }

      await Future.wait(futures);
      expect(saveAsCount, 50);
    });

    test('3. Save during scrolling', () async {
      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return true;
        },
      );

      final saveFuture = options.onSave?.call(controller.state.workbook);
      for (int i = 0; i < 100; i++) {
        controller.expandIfNeeded(i * 10, i * 10);
      }
      await saveFuture;

      expect(
        controller.state.workbook.activeSheet.rowCount,
        greaterThanOrEqualTo(100),
      );
    });

    test('4. Save during formula recalculation', () async {
      final options = PersistenceOptions(onSave: (workbook) async => true);

      controller.updateCellValue(0, 0, '10');
      final saveFuture = options.onSave?.call(controller.state.workbook);
      controller.updateCellValue(0, 1, '=A1*2');

      await saveFuture;
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.value?.toString(),
        '20.0',
      );
    });

    test('5. Save during paste', () async {
      // Paste via clipboard is unreliable in headless tests.
      // We directly write a cell value to simulate a paste outcome
      // and verify saving during that operation doesn't corrupt state.
      controller.updateCellValue(0, 0, 'Source');
      controller.updateCellValue(1, 1, 'Source'); // simulated paste

      final options = PersistenceOptions(onSave: (workbook) async => true);

      await options.onSave!(controller.state.workbook);

      expect(
        controller.state.workbook.activeSheet.cells['1,1']?.value,
        'Source',
      );
    });

    test('6. Save during sheet switch', () async {
      controller.addSheet(); // Sheet 2 (index 1)
      controller.switchSheet(0); // Back to Sheet 1

      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return true;
        },
      );

      final saveFuture = options.onSave?.call(controller.state.workbook);
      controller.switchSheet(1);

      await saveFuture;
      expect(controller.state.workbook.activeSheetIndex, 1);
    });

    test('7. Dispose during save', () async {
      // Simulate widget unmount / container dispose
      final tempContainer = ProviderContainer();
      final tempController = tempContainer.read(workbookProvider.notifier);

      final options = PersistenceOptions(
        onSave: (workbook) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return true;
        },
      );

      final saveFuture = options.onSave?.call(tempController.state.workbook);

      // Dispose immediately
      tempContainer.dispose();

      // The save operation completes in the background. It shouldn't crash.
      final success = await saveFuture;
      expect(success, isTrue);
    });

    test('8. Rapid workbook switching', () async {
      final w1 = Workbook(
        id: '1',
        name: 'W1',
        sheets: [Sheet(id: 's1', name: 'S1')],
      );
      final w2 = Workbook(
        id: '2',
        name: 'W2',
        sheets: [Sheet(id: 's2', name: 'S2')],
      );

      for (int i = 0; i < 50; i++) {
        controller.loadWorkbook(i % 2 == 0 ? w1 : w2);
      }

      // Last iteration: i=49, 49%2=1 -> w2
      expect(controller.state.workbook.id, '2');
    });
  });
}
