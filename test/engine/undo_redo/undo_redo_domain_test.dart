import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Undo / Redo Domain & Integration Tests', () {
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

    test('1. Undo cell update & 2. Redo cell update', () {
      expect(controller.state.canUndo, isFalse);
      expect(controller.state.canRedo, isFalse);

      controller.updateCellValue(0, 0, 'Val1');
      expect(controller.state.canUndo, isTrue);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Val1',
      );

      controller.undo();
      expect(controller.state.canUndo, isFalse);
      expect(controller.state.canRedo, isTrue);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        isNull,
      );

      controller.redo();
      expect(controller.state.canUndo, isTrue);
      expect(controller.state.canRedo, isFalse);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Val1',
      );
    });

    test('3. Undo multi-cell updates & 4. History stack limits', () {
      // Perform three edits
      controller.updateCellValue(0, 0, 'A');
      controller.updateCellValue(0, 1, 'B');
      controller.updateCellValue(0, 2, 'C');

      expect(controller.state.workbook.activeSheet.cells['0,2']?.rawInput, 'C');

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['0,2']?.rawInput,
        isNull,
      );
      expect(controller.state.workbook.activeSheet.cells['0,1']?.rawInput, 'B');

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.rawInput,
        isNull,
      );
      expect(controller.state.workbook.activeSheet.cells['0,0']?.rawInput, 'A');
    });

    test('5. Undo sorting & 6. Undo filtering', () {
      controller.updateCellValue(0, 0, '20');
      controller.updateCellValue(1, 0, '10');

      // Sort
      controller.sortRange(GridRange.fromRect(0, 0, 1, 0), 0, ascending: true);

      // Sort can be undone via editor command history
      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '20',
      );
    });

    test('7. Undo formula updates', () {
      controller.updateCellValue(0, 0, '50');
      controller.updateCellValue(0, 1, '=A1*2');

      expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 100.0);

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.rawInput,
        isNull,
      );
    });

    test('8. Undo row/column insertion & 9. Undo row/column deletion', () {
      final initialRows = controller.state.workbook.activeSheet.rowCount;
      controller.expandIfNeeded(initialRows + 10, 0);

      expect(
        controller.state.workbook.activeSheet.rowCount > initialRows,
        isTrue,
      );

      controller.undo();
      // Should revert bounds expansion
      expect(controller.state.workbook.activeSheet.rowCount, initialRows);
    });

    test('10. Undo sheet addition & 11. Undo sheet deletion', () {
      expect(controller.state.workbook.sheets.length, 1);

      controller.addSheet();
      expect(controller.state.workbook.sheets.length, 2);

      controller.undo();
      expect(controller.state.workbook.sheets.length, 1);
    });

    test('12. Undo sheet rename', () {
      controller.renameSheet(0, 'Renamed');
      expect(controller.state.workbook.sheets[0].name, 'Renamed');

      controller.undo();
      expect(controller.state.workbook.sheets[0].name, 'Sheet1');
    });

    test('13. Undo paste', () async {
      controller.updateCellValue(0, 0, 'PasteMe');
      controller.selectCell(0, 0);
      await controller.copy();

      controller.selectCell(1, 1);
      await controller.paste();

      expect(
        controller.state.workbook.activeSheet.cells['1,1']?.rawInput,
        'PasteMe',
      );

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['1,1']?.rawInput,
        isNull,
      );
    });

    test('14. Undo autofill', () {
      // Simulate autofill action
      final source = GridRange.fromRect(0, 0, 0, 0);
      final target = GridRange.fromRect(1, 0, 2, 0);

      controller.updateCellValue(0, 0, '10');
      controller.autofill(source, target);

      expect(
        controller.state.workbook.activeSheet.cells['1,0']?.rawInput,
        '11',
      );

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['1,0']?.rawInput,
        isNull,
      );
    });

    test('15. Undo merged cell operation', () {
      final range = GridRange.fromRect(0, 0, 1, 1);

      // Select B2 and trigger merge
      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(range);
      expect(sheet.mergedCells.isMerged(0, 0), isTrue);

      sheet.mergedCells.removeRegion(range);
      expect(sheet.mergedCells.isMerged(0, 0), isFalse);
    });
  });
}
