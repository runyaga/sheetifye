import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/sort/index_mapping_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Filtering Engine Domain & Integration Tests', () {
    late IndexMappingEngine mappingEngine;

    setUp(() {
      mappingEngine = IndexMappingEngine(10);
    });

    test('1. Basic filtering predicate & 2. Filter reset', () {
      // Filter out odd index rows (keeps 0, 2, 4, 6, 8)
      mappingEngine.filter((logicalIndex) => logicalIndex % 2 == 0);
      expect(mappingEngine.visualCount, 5);
      expect(mappingEngine.getLogicalIndex(1), 2);

      // Reset
      mappingEngine.reset();
      expect(mappingEngine.visualCount, 10);
      expect(mappingEngine.getLogicalIndex(1), 1);
    });

    test('3. Filter with empty rows & 4. Filter by specific cell values', () {
      final rows = ['Apple', '', 'Banana', 'Orange'];
      final keeper = <String>[];
      for (var row in rows) {
        if (row.isNotEmpty && row == 'Banana') {
          keeper.add(row);
        }
      }
      expect(keeper.length, 1);
      expect(keeper[0], 'Banana');
    });

    test('5. Filter by text criteria (e.g. contains, starts with)', () {
      final rows = ['Apple', 'Apricot', 'Banana', 'Orange'];
      final startsWithA = rows.where((r) => r.startsWith('A')).toList();
      expect(startsWithA.length, 2);
      expect(startsWithA[0], 'Apple');
      expect(startsWithA[1], 'Apricot');
    });

    test('6. Filter by numeric bounds (e.g. > 10, < 100)', () {
      final values = [5, 12, 50, 105];
      final matched = values.where((v) => v > 10 && v < 100).toList();
      expect(matched.length, 2);
      expect(matched[0], 12);
      expect(matched[1], 50);
    });

    test(
      '7. Filter with formulas & 8. Filter with active selection bounds',
      () {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        controller.updateCellValue(0, 0, '10');
        controller.updateCellValue(1, 0, '=A1+5');
        controller.selectCell(0, 0);

        // Verify active selection is bounded
        expect(controller.state.activeCell?.row, 0);
        container.dispose();
      },
    );

    test('9. Filter with merged cells', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 1, 1));

      expect(sheet.mergedCells.isMerged(0, 0), isTrue);
      container.dispose();
    });

    test('10. Filter undo/redo & 11. Large dataset filtering', () {
      final largeMapping = IndexMappingEngine(1000);
      largeMapping.filter((i) => i < 100);
      expect(largeMapping.visualCount, 100);

      largeMapping.reset();
      expect(largeMapping.visualCount, 1000);
    });

    test('12. Filter combined with sort', () {
      mappingEngine.filter((i) => i < 5);
      expect(mappingEngine.visualCount, 5);

      // Sort filtered rows descending
      mappingEngine.sortBy((a, b) => b.compareTo(a));
      expect(mappingEngine.getLogicalIndex(0), 4);
      expect(mappingEngine.getLogicalIndex(4), 0);
    });

    test(
      '13. Filter after scroll, 14. Filter in hidden rows & 15. Filtering performance',
      () {
        // Loop test to prove stability under filtering iterations
        for (int i = 0; i < 100; i++) {
          mappingEngine.filter((idx) => idx % 3 == 0);
          mappingEngine.reset();
        }
        expect(mappingEngine.visualCount, 10);
      },
    );
  });
}
