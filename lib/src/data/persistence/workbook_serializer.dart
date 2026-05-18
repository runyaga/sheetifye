import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/domain/entities/cell.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';

class WorkbookSerializer {
  Map<String, dynamic> serialize(Workbook workbook) {
    return {
      'version': '1.0',
      'id': workbook.id,
      'name': workbook.name,
      'activeSheetIndex': workbook.activeSheetIndex,
      'sheets': workbook.sheets.map((s) => _serializeSheet(s)).toList(),
    };
  }

  Map<String, dynamic> _serializeSheet(Sheet sheet) {
    return {
      'id': sheet.id,
      'name': sheet.name,
      'rowCount': sheet.rowCount,
      'columnCount': sheet.columnCount,
      'frozenRows': sheet.frozenRows,
      'frozenColumns': sheet.frozenColumns,
      'cells': sheet.cells.map((k, v) => MapEntry(k, _serializeCell(v))),
      'mergedRegions': sheet.mergedCells.regions
          .map(
            (r) => {
              'startRow': r.range.minRow,
              'endRow': r.range.maxRow,
              'startCol': r.range.minCol,
              'endCol': r.range.maxCol,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _serializeCell(Cell cell) {
    return {
      'id': cell.id,
      'row': cell.row,
      'column': cell.column,
      'value': cell.value,
      'rawInput': cell.rawInput,
      'formula': cell.formula,
      // Style would be serialized as a styleId or inline map
    };
  }

  Workbook deserialize(Map<String, dynamic> json) {
    return Workbook(
      id: json['id'] as String? ?? 'workbook-1',
      name: json['name'] as String? ?? 'Untitled',
      activeSheetIndex: json['activeSheetIndex'] as int? ?? 0,
      sheets:
          (json['sheets'] as List<dynamic>?)
              ?.map((s) => _deserializeSheet(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Sheet _deserializeSheet(Map<String, dynamic> json) {
    final cellsMap = <String, Cell>{};
    if (json['cells'] != null) {
      final Map<String, dynamic> cellsJson =
          json['cells'] as Map<String, dynamic>;
      for (final entry in cellsJson.entries) {
        cellsMap[entry.key] = _deserializeCell(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    final sheet = Sheet(
      id: json['id'] as String? ?? 'sheet-1',
      name: json['name'] as String? ?? 'Sheet1',
      rowCount: json['rowCount'] as int? ?? 1000,
      columnCount: json['columnCount'] as int? ?? 26,
      frozenRows: json['frozenRows'] as int? ?? 0,
      frozenColumns: json['frozenColumns'] as int? ?? 0,
      cells: cellsMap,
    );

    if (json['mergedRegions'] != null) {
      final List<dynamic> regions = json['mergedRegions'] as List<dynamic>;
      for (final r in regions) {
        final regionMap = r as Map<String, dynamic>;
        sheet.mergedCells.addRegion(
          GridRange.fromRect(
            regionMap['startRow'] as int,
            regionMap['startCol'] as int,
            regionMap['endRow'] as int,
            regionMap['endCol'] as int,
          ),
        );
      }
    }

    return sheet;
  }

  Cell _deserializeCell(Map<String, dynamic> json) {
    return Cell(
      id: json['id'] as String? ?? '0,0',
      row: json['row'] as int? ?? 0,
      column: json['column'] as int? ?? 0,
      value: json['value'],
      rawInput: json['rawInput'] as String?,
      formula: json['formula'] as String?,
    );
  }
}
