class GridCoordinate {
  final int row;
  final int column;

  const GridCoordinate(this.row, this.column);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridCoordinate &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          column == other.column;

  @override
  int get hashCode => row.hashCode ^ column.hashCode;

  @override
  String toString() => '($row, $column)';

  String toA1() {
    String colName = '';
    int tempCol = column;
    while (tempCol >= 0) {
      colName = String.fromCharCode((tempCol % 26) + 65) + colName;
      tempCol = (tempCol / 26).floor() - 1;
    }
    return '$colName${row + 1}';
  }
}

class GridRange {
  final GridCoordinate start;
  final GridCoordinate end;

  const GridRange({required this.start, required this.end});

  factory GridRange.fromRect(int minRow, int minCol, int maxRow, int maxCol) {
    return GridRange(
      start: GridCoordinate(minRow, minCol),
      end: GridCoordinate(maxRow, maxCol),
    );
  }

  int get minRow => start.row < end.row ? start.row : end.row;
  int get maxRow => start.row > end.row ? start.row : end.row;
  int get minCol => start.column < end.column ? start.column : end.column;
  int get maxCol => start.column > end.column ? start.column : end.column;

  bool contains(int row, int col) {
    return row >= minRow && row <= maxRow && col >= minCol && col <= maxCol;
  }

  bool intersects(GridRange other) {
    return !(maxRow < other.minRow ||
        minRow > other.maxRow ||
        maxCol < other.minCol ||
        minCol > other.maxCol);
  }

  bool containsRange(GridRange other) {
    return minRow <= other.minRow &&
        maxRow >= other.maxRow &&
        minCol <= other.minCol &&
        maxCol >= other.maxCol;
  }

  GridRange expandToInclude(GridRange other) {
    return GridRange(
      start: GridCoordinate(
        minRow < other.minRow ? minRow : other.minRow,
        minCol < other.minCol ? minCol : other.minCol,
      ),
      end: GridCoordinate(
        maxRow > other.maxRow ? maxRow : other.maxRow,
        maxCol > other.maxCol ? maxCol : other.maxCol,
      ),
    );
  }
}

class GridUtils {
  static GridCoordinate parseAddress(String address) {
    String addr = address;
    if (address.contains('!')) {
      final parts = address.split('!');
      addr = parts.last;
    }
    final match = RegExp(r'^([A-Z]+)([0-9]+)$').firstMatch(
      addr.toUpperCase().replaceAll('\$', ''),
    ); // strip $ for absolute references
    if (match == null) throw Exception('Invalid address: $address');

    final colStr = match.group(1)!;
    final rowStr = match.group(2)!;

    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }

    return GridCoordinate(int.parse(rowStr) - 1, col - 1);
  }

  static GridRange parseRange(String range) {
    String rng = range;
    if (range.contains('!')) {
      final parts = range.split('!');
      rng = parts.last;
    }
    final parts = rng.split(':');
    if (parts.length != 2) throw Exception('Invalid range: $range');
    return GridRange(
      start: parseAddress(parts[0]),
      end: parseAddress(parts[1]),
    );
  }

  static String getAddress(int row, int col) {
    String colName = '';
    int tempCol = col;
    while (tempCol >= 0) {
      colName = String.fromCharCode((tempCol % 26) + 65) + colName;
      tempCol = (tempCol / 26).floor() - 1;
    }
    return '$colName${row + 1}';
  }

  static String getColumnLabel(int col) {
    String label = '';
    while (col >= 0) {
      label = String.fromCharCode((col % 26) + 65) + label;
      col = (col / 26).floor() - 1;
    }
    return label;
  }

  /// Formats and escapes a single field for CSV compliance.
  static String formatCSVField(String value) {
    if (value.contains(',') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value.contains('"')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Parses an RFC-4180 compliant CSV string, supporting newlines within quotes.
  static List<List<String>> parseCSV(String text) {
    final List<List<String>> grid = [];
    List<String> currentRow = [];
    final int len = text.length;

    int i = 0;
    while (i < len) {
      if (currentRow.isEmpty && (text[i] == '\n' || text[i] == '\r')) {
        if (text[i] == '\r') {
          i++;
          if (i < len && text[i] == '\n') i++;
        } else {
          i++;
        }
        grid.add([]);
        continue;
      }

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
          if (text[i] == ',') {
            i++;
            if (i == len) {
              currentRow.add('');
            }
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
            text[i] != ',' &&
            text[i] != '\n' &&
            text[i] != '\r') {
          buffer.write(text[i]);
          i++;
        }
        currentRow.add(buffer.toString());

        if (i < len) {
          if (text[i] == ',') {
            i++;
            if (i == len) {
              currentRow.add('');
            }
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

    // Filter trailing empty lines often generated by final splits
    if (grid.isNotEmpty &&
        (grid.last.isEmpty ||
            (grid.last.length == 1 && grid.last[0].isEmpty))) {
      grid.removeLast();
    }

    return grid;
  }
}
