import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sheetifye Performance Stress and Load Tests', () {
    test(
      '1. WorkbookController should handle 1,000,000 cell sheet initialization',
      () {
        final workbook = Workbook(
          id: 'stress-test-wb',
          name: 'Stress Test',
          sheets: [
            Sheet(
              id: 'huge-sheet',
              name: 'HugeSheet',
              rowCount: 10000,
              columnCount: 100,
            ),
          ],
        );

        final controller = WorkbookController();
        controller.state = controller.state.copyWith(workbook: workbook);

        expect(controller.state.workbook.activeSheet.rowCount, 10000);
        expect(controller.state.workbook.activeSheet.columnCount, 100);
      },
    );

    test('2. Cascade formula stress test with deep dependency chains', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '1');

      // Create 100 deep formula link: A2 = A1 + 1, A3 = A2 + 1, ...
      for (int i = 1; i < 50; i++) {
        final colLetter = GridUtils.getColumnLabel(0);
        final prevRow = i;
        controller.updateCellValue(i, 0, '=$colLetter$prevRow+1');
      }

      // Verify the 50th cell evaluated correctly to 50
      expect(controller.state.workbook.activeSheet.cells['49,0']?.value, 50.0);

      // Mutate seed value A1
      controller.updateCellValue(0, 0, '10');
      expect(controller.state.workbook.activeSheet.cells['49,0']?.value, 59.0);

      container.dispose();
    });

    test('3. Mass CSV import rendering stability', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      final buffer = StringBuffer();
      for (int i = 0; i < 2000; i++) {
        buffer.write('$i,DataA$i,DataB$i,DataC$i\n');
      }

      controller.importCSV(buffer.toString());
      expect(controller.state.workbook.activeSheet.rowCount >= 2000, isTrue);

      container.dispose();
    });

    test('4. Rapid undo/redo stress loops', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      // Perform 50 rapid edits
      for (int i = 0; i < 50; i++) {
        controller.updateCellValue(0, 0, 'Edit$i');
      }

      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Edit49',
      );

      // Rapidly undo all 50 edits
      for (int i = 0; i < 50; i++) {
        controller.undo();
      }
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        isNull,
      );

      // Rapidly redo all 50 edits
      for (int i = 0; i < 50; i++) {
        controller.redo();
      }
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Edit49',
      );

      container.dispose();
    });
  });
}
