import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/src/engine/sort/index_mapping_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sorting and Filtering Domain Tests', () {
    late IndexMappingEngine mappingEngine;

    setUp(() {
      mappingEngine = IndexMappingEngine(10);
    });

    test('Should translate visual indices to logical indices correctly', () {
      // Initially, visual matches logical 1:1
      expect(mappingEngine.getLogicalIndex(0), 0);
      expect(mappingEngine.getLogicalIndex(5), 5);

      // We can sort using comparator to rearrange indices:
      // Let's sort descending so visual 0 maps to logical 9
      mappingEngine.sortBy((a, b) => b.compareTo(a));
      expect(mappingEngine.getLogicalIndex(0), 9);
      expect(mappingEngine.getLogicalIndex(9), 0);
    });

    test('Should support filtering of indexes and resets', () {
      // Filter out odd index rows (predicate keeps even rows)
      mappingEngine.filter((logicalIndex) => logicalIndex % 2 == 0);
      expect(mappingEngine.visualCount, 5); // 0, 2, 4, 6, 8
      expect(mappingEngine.getLogicalIndex(1), 2); // Visual row 1 is logical 2

      mappingEngine.reset();
      expect(mappingEngine.visualCount, 10);
      expect(mappingEngine.getLogicalIndex(1), 1);
    });
  });
}
