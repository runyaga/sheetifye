import 'package:sheetifye/src/engine/commands/spreadsheet_command.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/domain/entities/cell.dart';

class UpdateCellCommand extends SpreadsheetCommand {
  final int row;
  final int col;
  final dynamic newValue;
  Cell? _oldCell;

  UpdateCellCommand({
    required this.row,
    required this.col,
    required this.newValue,
  });

  @override
  String get label => 'Update Cell';

  @override
  void execute(Workbook workbook) {
    final sheet = workbook.activeSheet;
    _oldCell = sheet.cells['$row,$col'];

    final String valStr = newValue?.toString() ?? '';
    final bool isFormula = valStr.startsWith('=');
    sheet.cells['$row,$col'] = Cell(
      id: '$row,$col',
      row: row,
      column: col,
      value: isFormula ? null : newValue,
      rawInput: valStr,
      formula: isFormula ? valStr : null,
    );
  }

  @override
  void undo(Workbook workbook) {
    final sheet = workbook.activeSheet;
    if (_oldCell != null) {
      sheet.cells['$row,$col'] = _oldCell!;
    } else {
      sheet.cells.remove('$row,$col');
    }
  }
}

class UpdateRangeCommand extends SpreadsheetCommand {
  final Map<String, dynamic> newValues;
  final Map<String, Cell> _oldCells = {};

  UpdateRangeCommand(this.newValues);

  @override
  String get label => 'Update Range';

  @override
  void execute(Workbook workbook) {
    final sheet = workbook.activeSheet;
    newValues.forEach((key, value) {
      final parts = key.split(',');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);

      if (sheet.cells.containsKey(key)) {
        _oldCells[key] = sheet.cells[key]!;
      } else {
        _oldCells[key] = Cell(id: key, row: row, column: col, value: null);
      }

      final String valStr = value?.toString() ?? '';
      final bool isFormula = valStr.startsWith('=');
      sheet.cells[key] = Cell(
        id: key,
        row: row,
        column: col,
        value: isFormula ? null : value,
        rawInput: valStr,
        formula: isFormula ? valStr : null,
      );
    });
  }

  @override
  void undo(Workbook workbook) {
    final sheet = workbook.activeSheet;
    _oldCells.forEach((key, cell) {
      if (cell.value == null && cell.rawInput == null && cell.formula == null) {
        sheet.cells.remove(key);
      } else {
        sheet.cells[key] = cell;
      }
    });
  }
}
