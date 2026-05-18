import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/formula/recalculation_engine.dart';
import 'package:sheetifye/src/engine/structure/reference_shift_engine.dart';
import 'package:sheetifye/src/engine/formula/function_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Formula Engine Domain Tests', () {
    late RecalculationEngine recalculationEngine;
    late ReferenceShiftEngine shiftEngine;
    late Sheet sheet;

    setUp(() {
      recalculationEngine = RecalculationEngine();
      shiftEngine = ReferenceShiftEngine();
      sheet = Sheet(
        id: 'formula-sheet',
        name: 'Sheet1',
        rowCount: 10,
        columnCount: 10,
      );
    });

    test('1. Basic arithmetic operations (+, -, *, /)', () {
      dynamic result;
      recalculationEngine.processCellUpdate(
        '0,0',
        '=100-20',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 80);

      recalculationEngine.processCellUpdate(
        '0,0',
        '=5*6',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 30);

      recalculationEngine.processCellUpdate(
        '0,0',
        '=20/5',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 4.0);
    });

    test('2. Operator precedence', () {
      dynamic result;
      recalculationEngine.processCellUpdate(
        '0,0',
        '=10+5*2',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 20); // 10 + (5*2) = 20

      recalculationEngine.processCellUpdate(
        '0,0',
        '=(10+5)*2',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 30);
    });

    test('3. Nested formulas', () {
      dynamic result;
      // Nesting using parenthesis and operations
      recalculationEngine.processCellUpdate(
        '0,0',
        '=5*(3+(10/2))',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 40.0);
    });

    test('4. SUM over range', () {
      dynamic result;
      sheet.cells['0,0'] = const Cell(id: '0,0', row: 0, column: 0, value: 10);
      sheet.cells['1,0'] = const Cell(id: '1,0', row: 1, column: 0, value: 20);
      sheet.cells['2,0'] = const Cell(id: '2,0', row: 2, column: 0, value: 30);

      recalculationEngine.processCellUpdate(
        '3,0',
        '=SUM(A1:A3)',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 60.0);
    });

    test('5. AVG / MIN / MAX custom registered function verification', () {
      final registry = FunctionRegistry();

      // Register custom functions
      registry.register('AVG', (args) {
        if (args.isEmpty) return 0;
        double sum = 0;
        int count = 0;
        for (var arg in args) {
          if (arg is Iterable) {
            for (var v in arg) {
              if (v is num) {
                sum += v;
                count++;
              }
            }
          } else if (arg is num) {
            sum += arg;
            count++;
          }
        }
        return count == 0 ? 0 : sum / count;
      });

      registry.register('MIN', (args) {
        if (args.isEmpty) return 0;
        double? minVal;
        for (var arg in args) {
          if (arg is Iterable) {
            for (var v in arg) {
              if (v is num) {
                if (minVal == null || v < minVal) minVal = v.toDouble();
              }
            }
          } else if (arg is num) {
            if (minVal == null || arg < minVal) minVal = arg.toDouble();
          }
        }
        return minVal ?? 0;
      });

      registry.register('MAX', (args) {
        if (args.isEmpty) return 0;
        double? maxVal;
        for (var arg in args) {
          if (arg is Iterable) {
            for (var v in arg) {
              if (v is num) {
                if (maxVal == null || v > maxVal) maxVal = v.toDouble();
              }
            }
          } else if (arg is num) {
            if (maxVal == null || arg > maxVal) maxVal = arg.toDouble();
          }
        }
        return maxVal ?? 0;
      });

      expect(registry.execute('AVG', [10, 20, 30]), 20.0);
      expect(
        registry.execute('MIN', [
          [5, 12, 3],
          8,
        ]),
        3.0,
      );
      expect(
        registry.execute('MAX', [
          15,
          [40, 25],
        ]),
        40.0,
      );
    });

    test('6. IF condition logic', () {
      dynamic result;
      sheet.cells['0,0'] = const Cell(id: '0,0', row: 0, column: 0, value: 5);

      recalculationEngine.processCellUpdate(
        '1,0',
        '=IF(A1,100,200)',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 100);

      sheet.cells['0,0'] = const Cell(id: '0,0', row: 0, column: 0, value: 0);
      recalculationEngine.processCellUpdate(
        '1,0',
        '=IF(A1,100,200)',
        sheet,
        (addr, val) => result = val,
      );
      expect(result, 200);
    });

    test('7. Relative formula shifting', () {
      final shifted = shiftEngine.shiftFormula(
        '=A1*2',
        rowAt: 0,
        rowCount: 3,
        colAt: 0,
        colCount: 2,
      );
      expect(shifted, '=(C4 * 2.0)');
    });

    test('8. Absolute formula coordinates locking (\$)', () {
      final shifted = shiftEngine.shiftFormula(
        '=\$A\$1*2',
        rowAt: 0,
        rowCount: 3,
        colAt: 0,
        colCount: 2,
      );
      expect(shifted, '=(\$A\$1 * 2.0)');
    });

    test('9. Mixed references (e.g. \$A1 or A\$1) shifting', () {
      // Row is absolute, Col shifts
      final shifted1 = shiftEngine.shiftFormula(
        '=A\$1*2',
        rowAt: 0,
        rowCount: 3,
        colAt: 0,
        colCount: 2,
      );
      expect(shifted1, '=(C\$1 * 2.0)');

      // Col is absolute, Row shifts
      final shifted2 = shiftEngine.shiftFormula(
        '=\$A1*2',
        rowAt: 0,
        rowCount: 3,
        colAt: 0,
        colCount: 2,
      );
      expect(shifted2, '=(\$A4 * 2.0)');
    });

    test('10. Cross-sheet references qualifiers shifted correctly', () {
      final shifted = shiftEngine.shiftFormula(
        "='Sales Summary'!B2+10",
        rowAt: 0,
        rowCount: 2,
        colAt: 0,
        colCount: 1,
      );
      expect(shifted, "=('Sales Summary'!C4 + 10.0)");
    });
  });
}
