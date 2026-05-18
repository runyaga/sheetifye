import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/engine/formula/recalculation_engine.dart';

void main() {
  group('Formula Engine Reliability', () {
    late RecalculationEngine engine;
    late Sheet sheet;

    setUp(() {
      engine = RecalculationEngine();
      sheet = Sheet(
        id: 'test-sheet',
        name: 'TestSheet',
        rowCount: 10,
        columnCount: 10,
      );
    });

    test('Should evaluate simple arithmetic formulas', () {
      dynamic result;
      engine.processCellUpdate(
        '0,0',
        '=10+20*2',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 50);
    });
  });
}
