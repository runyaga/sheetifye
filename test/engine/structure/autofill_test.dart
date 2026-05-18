import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/autofill/autofill_engine.dart';

void main() {
  group('AutofillEngine Tests', () {
    late AutofillEngine autofillEngine;
    late Sheet sheet;

    setUp(() {
      autofillEngine = AutofillEngine();
      sheet = Sheet(
        id: 'test-sheet',
        name: 'TestSheet',
        rowCount: 10,
        columnCount: 10,
      );

      // Populate some test cells
      sheet.cells['0,0'] = const Cell(
        id: '0,0',
        row: 0,
        column: 0,
        value: 10,
        rawInput: '10',
      ); // A1
      sheet.cells['1,0'] = const Cell(
        id: '1,0',
        row: 1,
        column: 0,
        value: null,
        rawInput: '=A1+5',
        formula: '=A1+5',
      ); // A2
    });

    test('Should auto-increment numeric series vertically', () {
      final source = GridRange.fromRect(0, 0, 0, 0); // A1
      final target = GridRange.fromRect(1, 0, 3, 0); // A2:A4

      final fill = autofillEngine.generateFill(source, target, sheet);

      // A1 has value 10.
      // Vertical step +1 offset -> 11
      // Vertical step +2 offset -> 12
      // Vertical step +3 offset -> 13
      expect(fill['1,0'], '11');
      expect(fill['2,0'], '12');
      expect(fill['3,0'], '13');
    });

    test('Should shift formulas when filling vertically', () {
      final source = GridRange.fromRect(1, 0, 1, 0); // A2 (=A1+5)
      final target = GridRange.fromRect(2, 0, 3, 0); // A3:A4

      final fill = autofillEngine.generateFill(source, target, sheet);

      // Shift vertically:
      // A2 (=A1+5) shifted to A3 (row+1) becomes =A2+5
      // A2 (=A1+5) shifted to A4 (row+2) becomes =A3+5
      expect(fill['2,0'], '=(A2 + 5.0)');
      expect(fill['3,0'], '=(A3 + 5.0)');
    });

    test('Should shift formulas when filling horizontally', () {
      final source = GridRange.fromRect(1, 0, 1, 0); // A2 (=A1+5)
      final target = GridRange.fromRect(1, 1, 1, 2); // B2:C2

      final fill = autofillEngine.generateFill(source, target, sheet);

      // Shift horizontally:
      // A2 (=A1+5) shifted to B2 (col+1) becomes =B1+5
      // A2 (=A1+5) shifted to C2 (col+2) becomes =C1+5
      expect(fill['1,1'], '=(B1 + 5.0)');
      expect(fill['1,2'], '=(C1 + 5.0)');
    });
  });
}
