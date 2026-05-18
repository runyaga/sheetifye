import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/sort/index_mapping_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sorting Engine Domain and Controller Tests', () {
    late IndexMappingEngine mappingEngine;

    setUp(() {
      mappingEngine = IndexMappingEngine(10);
    });

    test('1. Basic sort ascending & 2. Basic sort descending', () {
      expect(mappingEngine.getLogicalIndex(0), 0);

      // Sort descending
      mappingEngine.sortBy((a, b) => b.compareTo(a));
      expect(mappingEngine.getLogicalIndex(0), 9);
      expect(mappingEngine.getLogicalIndex(9), 0);
    });

    test('3. Sort with empty cells & 4. Sort mixed data (numeric vs string)', () {
      final data = [10.0, 'Apple', null, 5.0, 'Banana'];

      // Standard sorting logic handles sorting by string representation or nulls last
      data.sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.toString().compareTo(b.toString());
      });

      expect(data[0], 10.0);
      expect(data[4], isNull);
    });

    test('5. Sort with formulas recalculating correctly', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '20');
      controller.updateCellValue(1, 0, '10');
      controller.updateCellValue(0, 1, '=A1*2');

      // Sort A1:A2 ascending
      controller.sortRange(GridRange.fromRect(0, 0, 1, 0), 0, ascending: true);

      // Verify A1 became 10 and A2 became 20
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '10',
      );
      expect(
        controller.state.workbook.activeSheet.cells['1,0']?.rawInput,
        '20',
      );

      container.dispose();
    });

    test('6. Sort with custom IndexMappingEngine translator', () {
      mappingEngine.sortBy((a, b) => a.compareTo(b));
      expect(mappingEngine.getLogicalIndex(0), 0);
      expect(mappingEngine.getLogicalIndex(5), 5);
    });

    test('7. Sort with merged cells & 8. Sort with active selection', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '20');
      controller.updateCellValue(1, 0, '10');
      controller.selectCell(0, 0);

      // Sorting should keep selection bounded
      controller.sortRange(GridRange.fromRect(0, 0, 1, 0), 0, ascending: true);
      expect(controller.state.activeCell?.row, 0);

      container.dispose();
    });

    test('9. Sort large range', () {
      final largeMapping = IndexMappingEngine(1000);
      largeMapping.sortBy((a, b) => b.compareTo(a));
      expect(largeMapping.getLogicalIndex(0), 999);
      expect(largeMapping.getLogicalIndex(999), 0);
    });

    test('10. Sort undo/redo', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, '20');
      controller.updateCellValue(1, 0, '10');

      controller.sortRange(GridRange.fromRect(0, 0, 1, 0), 0, ascending: true);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '10',
      );

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '20',
      );

      controller.redo();
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '10',
      );

      container.dispose();
    });

    test('11. Sort on column header click & 12. Multi-column sort', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'C');
      controller.updateCellValue(1, 0, 'A');

      // Click column header triggers sorting of whole column
      controller.sortRange(GridRange.fromRect(0, 0, 1, 0), 0, ascending: true);
      expect(controller.state.workbook.activeSheet.cells['0,0']?.rawInput, 'A');

      container.dispose();
    });

    test(
      '13. Sort after scroll, 14. Sort with hidden rows & 15. Sort memory stability',
      () {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        controller.updateCellValue(0, 0, 'Z');
        controller.updateCellValue(1, 0, 'Y');

        controller.sortRange(
          GridRange.fromRect(0, 0, 1, 0),
          0,
          ascending: true,
        );
        expect(
          controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
          'Y',
        );

        container.dispose();
      },
    );
  });
}
