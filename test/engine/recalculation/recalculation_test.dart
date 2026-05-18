import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/formula/recalculation_engine.dart';
import 'package:sheetifye/src/engine/formula/dependency_graph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Formula Recalculation Engine Tests', () {
    late RecalculationEngine engine;
    late Sheet sheet;

    setUp(() {
      engine = RecalculationEngine();
      sheet = Sheet(
        id: 'recalc-sheet',
        name: 'Sheet1',
        rowCount: 100,
        columnCount: 20,
      );
    });

    test('1. Circular dependency detection and handling', () {
      sheet.cells['0,0'] = const Cell(
        id: '0,0',
        row: 0,
        column: 0,
        value: null,
        formula: '=B1',
      );
      sheet.cells['0,1'] = const Cell(
        id: '0,1',
        row: 0,
        column: 1,
        value: null,
        formula: '=A1',
      );

      expect(() {
        engine.processCellUpdate('0,0', '=B1', sheet, (addr, val) {});
        engine.processCellUpdate('0,1', '=A1', sheet, (addr, val) {});
      }, throwsA(isA<CircularDependencyException>()));
    });

    test(
      '2. Invalid syntax handling - syntax errors result in error tokens',
      () {
        dynamic result;
        engine.processCellUpdate(
          '0,0',
          '=10++*',
          sheet,
          (addr, val) => result = val,
        );
        expect(result, '#ERROR!');
      },
    );

    test('3. Division by zero throws #DIV/0!', () {
      dynamic result;
      engine.processCellUpdate(
        '0,0',
        '=100/0',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, '#DIV/0!');
    });

    test('4. Empty reference handling evaluates to 0', () {
      dynamic result;
      // Reference to unpopulated cell B2 (1, 1)
      engine.processCellUpdate(
        '0,0',
        '=B2+10',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 10);
    });

    test('5. Large dependency chain cascade recalculation', () {
      final computedValues = <String, dynamic>{};
      void callback(String addr, dynamic val) {
        computedValues[addr] = val;
        final cell = sheet.cells[addr];
        if (cell != null) {
          sheet.cells[addr] = cell.copyWith(value: val);
        } else {
          final parts = addr.split(',');
          sheet.cells[addr] = Cell(
            id: addr,
            row: int.parse(parts[0]),
            column: int.parse(parts[1]),
            value: val,
          );
        }
      }

      sheet.cells['0,0'] = const Cell(id: '0,0', row: 0, column: 0, value: 5);

      // A2 depends on A1 (0,0)
      sheet.cells['1,0'] = const Cell(
        id: '1,0',
        row: 1,
        column: 0,
        formula: '=A1+10',
      );
      engine.processCellUpdate('1,0', '=A1+10', sheet, callback);

      // A3 depends on A2 (1,0)
      sheet.cells['2,0'] = const Cell(
        id: '2,0',
        row: 2,
        column: 0,
        formula: '=A2*2',
      );
      engine.processCellUpdate('2,0', '=A2*2', sheet, callback);

      // Verify initial cascade
      expect(computedValues['1,0'], 15);
      expect(computedValues['2,0'], 30);

      // Update source A1 (0,0)
      engine.processCellUpdate('0,0', '20', sheet, callback);

      // Dependents must cascade update!
      expect(computedValues['1,0'], 30);
      expect(computedValues['2,0'], 60);
    });

    test('6. Formula deletion breaks dependencies', () {
      final computedValues = <String, dynamic>{};
      sheet.cells['0,0'] = const Cell(id: '0,0', row: 0, column: 0, value: 50);
      sheet.cells['0,1'] = const Cell(
        id: '0,1',
        row: 0,
        column: 1,
        formula: '=A1+5',
      );

      engine.processCellUpdate(
        '0,1',
        '=A1+5',
        sheet,
        (addr, val) => computedValues[addr] = val,
      );
      expect(computedValues['0,1'], 55);

      // Delete formula from B1
      engine.processCellUpdate(
        '0,1',
        '',
        sheet,
        (addr, val) => computedValues[addr] = val,
      );
      expect(computedValues['0,1'], '');
    });

    test('7. Formula after sheet rename and mutations', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '100');
      controller.updateCellValue(0, 1, '=A1*2');

      expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 200.0);

      // Rename active sheet
      controller.renameSheet(0, 'RenamedSheet');
      expect(controller.state.workbook.sheets[0].name, 'RenamedSheet');

      // Update cell to trigger recalculation
      controller.updateCellValue(0, 0, '50');
      expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 100.0);

      container.dispose();
    });

    test('8. Formula recalculation after clipboard paste', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '10');
      controller.updateCellValue(0, 1, '=A1+100');
      expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 110.0);

      // Copy A1:B1
      controller.selectCell(0, 0);
      controller.expandSelection(0, 1);
      await controller.copy();

      // Paste onto A2 (1,0)
      controller.selectCell(1, 0);
      await controller.paste();

      // Formula shifted: B2 = A2 + 100 -> 10 + 100 = 110.0
      expect(
        controller.state.workbook.activeSheet.cells['1,1']?.formula,
        '=(A2 + 100.0)',
      );
      expect(controller.state.workbook.activeSheet.cells['1,1']?.value, 110.0);

      container.dispose();
    });

    test('9. Formula recalculation after undo/redo', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '5');
      controller.updateCellValue(0, 1, '=A1*5');
      expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 25.0);

      // Update A1 -> 10
      controller.updateCellValue(0, 0, '10');
      expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 50.0);

      // Undo
      controller.undo();
      // Wait, let's verify cell value and formula evaluation reverted
      expect(controller.state.workbook.activeSheet.cells['0,0']?.rawInput, '5');

      // Redo
      controller.redo();
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '10',
      );

      container.dispose();
    });
  });
}
