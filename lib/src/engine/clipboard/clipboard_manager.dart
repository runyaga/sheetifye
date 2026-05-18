import 'package:flutter/services.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/engine/structure/reference_shift_engine.dart';

class ClipboardManager {
  GridRange? _copiedRange;
  Sheet? _copiedSheet;
  final _shiftEngine = ReferenceShiftEngine();

  Future<void> copyToClipboard(GridRange range, Sheet sheet) async {
    _copiedRange = range;
    _copiedSheet = sheet;

    final buffer = StringBuffer();
    for (int r = range.minRow; r <= range.maxRow; r++) {
      final logicalR = sheet.rowIndexManager.getLogicalIndex(r);
      final rowValues = <String>[];
      for (int c = range.minCol; c <= range.maxCol; c++) {
        final cell = sheet.cells['$logicalR,$c'];
        final val = cell?.rawInput ?? cell?.value?.toString() ?? '';
        rowValues.add(formatTSVField(val));
      }
      buffer.write(rowValues.join('\t'));
      if (r < range.maxRow) {
        buffer.write('\n');
      }
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  Future<Map<String, dynamic>?> getFromClipboard(
    GridCoordinate target,
    Sheet sheet,
  ) async {
    // Check if it's an in-app copy and paste operation (to preserve and shift formulas)
    if (_copiedRange != null && _copiedSheet != null) {
      final Map<String, dynamic> mutations = {};
      final rowOffset = target.row - _copiedRange!.minRow;
      final colOffset = target.column - _copiedRange!.minCol;

      for (int r = _copiedRange!.minRow; r <= _copiedRange!.maxRow; r++) {
        for (int c = _copiedRange!.minCol; c <= _copiedRange!.maxCol; c++) {
          final targetRow = r + rowOffset;
          final targetCol = c + colOffset;

          if (targetRow >= sheet.rowCount || targetCol >= sheet.columnCount) {
            continue;
          }

          final sourceLogicalR = _copiedSheet!.rowIndexManager.getLogicalIndex(
            r,
          );
          final targetLogicalR = sheet.rowIndexManager.getLogicalIndex(
            targetRow,
          );

          final sourceCell = _copiedSheet!.cells['$sourceLogicalR,$c'];
          if (sourceCell != null) {
            final String raw =
                sourceCell.rawInput ?? sourceCell.value?.toString() ?? '';
            if (raw.startsWith('=')) {
              // Shift the formula references by the row and column paste offsets
              mutations['$targetLogicalR,$targetCol'] = _shiftEngine
                  .shiftFormula(
                    raw,
                    rowAt: 0,
                    rowCount: rowOffset,
                    colAt: 0,
                    colCount: colOffset,
                  );
            } else {
              mutations['$targetLogicalR,$targetCol'] = raw;
            }
          } else {
            mutations['$targetLogicalR,$targetCol'] = null;
          }
        }
      }
      return mutations;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return null;

    final Map<String, dynamic> mutations = {};
    // Fallback: Parse RFC-4180 TSV plain text from the system clipboard
    final grid = parseTSV(data!.text!);
    for (int i = 0; i < grid.length; i++) {
      final cells = grid[i];
      final targetRow = target.row + i;
      if (targetRow >= sheet.rowCount) break;

      final targetLogicalR = sheet.rowIndexManager.getLogicalIndex(targetRow);

      for (int j = 0; j < cells.length; j++) {
        final targetCol = target.column + j;
        if (targetCol >= sheet.columnCount) break;

        mutations['$targetLogicalR,$targetCol'] = cells[j];
      }
    }
    return mutations;
  }

  /// Formats and escapes a single field for TSV serialization.
  String formatTSVField(String value) {
    if (value.contains('\t') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.contains('"')) {
      // Escape inner double quotes by doubling them, and wrap the field in double quotes
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Robust scanner to parse RFC-4180 compliant TSV string.
  List<List<String>> parseTSV(String text) {
    final List<List<String>> grid = [];
    List<String> currentRow = [];
    final int len = text.length;

    int i = 0;
    while (i < len) {
      if (text[i] == '"') {
        // Quoted field
        i++; // skip opening quote
        final StringBuffer buffer = StringBuffer();
        while (i < len) {
          if (text[i] == '"') {
            if (i + 1 < len && text[i + 1] == '"') {
              buffer.write('"');
              i += 2;
            } else {
              i++; // skip closing quote
              break;
            }
          } else {
            buffer.write(text[i]);
            i++;
          }
        }
        currentRow.add(buffer.toString());

        if (i < len) {
          if (text[i] == '\t') {
            i++;
          } else if (text[i] == '\r') {
            i++;
            if (i < len && text[i] == '\n') i++;
            grid.add(currentRow);
            currentRow = [];
          } else if (text[i] == '\n') {
            i++;
            grid.add(currentRow);
            currentRow = [];
          }
        }
      } else {
        // Unquoted field
        final StringBuffer buffer = StringBuffer();
        while (i < len &&
            text[i] != '\t' &&
            text[i] != '\n' &&
            text[i] != '\r') {
          buffer.write(text[i]);
          i++;
        }
        currentRow.add(buffer.toString());

        if (i < len) {
          if (text[i] == '\t') {
            i++;
          } else if (text[i] == '\r') {
            i++;
            if (i < len && text[i] == '\n') i++;
            grid.add(currentRow);
            currentRow = [];
          } else if (text[i] == '\n') {
            i++;
            grid.add(currentRow);
            currentRow = [];
          }
        }
      }
    }

    if (currentRow.isNotEmpty) {
      grid.add(currentRow);
    }

    // Filter trailing blank lines generated by split end artifacts
    if (grid.isNotEmpty && grid.last.length == 1 && grid.last[0].isEmpty) {
      grid.removeLast();
    }

    return grid;
  }
}
