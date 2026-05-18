import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/structure/reference_shift_engine.dart';

class AutofillEngine {
  final _shiftEngine = ReferenceShiftEngine();

  Map<String, String> generateFill(
    GridRange source,
    GridRange target,
    Sheet sheet,
  ) {
    final Map<String, String> results = {};

    final int srcHeight = source.maxRow - source.minRow + 1;
    final int srcWidth = source.maxCol - source.minCol + 1;

    for (int r = target.minRow; r <= target.maxRow; r++) {
      for (int c = target.minCol; c <= target.maxCol; c++) {
        // Map target coordinate (r, c) to source coordinate
        final int srcRowOffset = (r - target.minRow) % srcHeight;
        final int srcColOffset = (c - target.minCol) % srcWidth;
        final int srcRow = source.minRow + srcRowOffset;
        final int srcCol = source.minCol + srcColOffset;

        final sourceCell = sheet.cells['$srcRow,$srcCol'];
        if (sourceCell != null) {
          final String raw =
              sourceCell.rawInput ?? sourceCell.value?.toString() ?? '';
          if (raw.startsWith('=')) {
            // Shift formula by the offset between target and source cell
            final int rowShift = r - srcRow;
            final int colShift = c - srcCol;
            results['$r,$c'] = fillFormula(raw, rowShift, colShift);
          } else {
            // Numeric auto-increment logic
            final double? numVal = double.tryParse(raw);
            if (numVal != null) {
              final int stepRow = r - srcRow;
              final int stepCol = c - srcCol;
              final double diff = stepRow.toDouble() + stepCol.toDouble();
              final double newVal = numVal + diff;

              if (newVal == newVal.toInt()) {
                results['$r,$c'] = newVal.toInt().toString();
              } else {
                results['$r,$c'] = newVal.toString();
              }
            } else {
              results['$r,$c'] = raw;
            }
          }
        } else {
          results['$r,$c'] = '';
        }
      }
    }

    return results;
  }

  String fillFormula(String formula, int rowOffset, int colOffset) {
    if (!formula.startsWith('=')) return formula;

    // Autofill formula shifting is basically a reference shift by the offset
    return _shiftEngine.shiftFormula(
      formula,
      rowAt: 0,
      rowCount: rowOffset,
      colAt: 0,
      colCount: colOffset,
    );
  }
}
