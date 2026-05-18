import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/data/persistence/workbook_serializer.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';

class WorkbookExporter {
  /// Serializes the workbook to JSON format.
  static Map<String, dynamic> toJson(Workbook workbook) {
    return WorkbookSerializer().serialize(workbook);
  }

  /// Exports the active sheet (or specified sheet) to CSV format.
  static String toCsv(Workbook workbook, {int? sheetIndex}) {
    final sheet = workbook.sheets[sheetIndex ?? workbook.activeSheetIndex];
    int maxRow = 0;
    int maxCol = 0;
    bool hasCells = false;

    for (final key in sheet.cells.keys) {
      final parts = key.split(',');
      if (parts.length == 2) {
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        if (r > maxRow) maxRow = r;
        if (c > maxCol) maxCol = c;
        hasCells = true;
      }
    }

    if (!hasCells) return '';

    final buffer = StringBuffer();
    for (int r = 0; r <= maxRow; r++) {
      final rowValues = <String>[];
      for (int c = 0; c <= maxCol; c++) {
        final cell = sheet.cells['$r,$c'];
        final val = cell?.rawInput ?? cell?.value?.toString() ?? '';
        rowValues.add(GridUtils.formatCSVField(val));
      }
      buffer.write(rowValues.join(','));
      if (r < maxRow) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  /// Generates a minimal structural XLSX file.
  /// Note: This is a barebones implementation satisfying the lifecycle hook.
  /// Complex formulas, formatting, and multiple sheets may require a full
  /// external library implementation.
  static Uint8List toXlsxBytes(Workbook workbook) {
    final archive = Archive();

    // [Content_Types].xml
    const contentTypes =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypes.length,
        contentTypes.codeUnits,
      ),
    );

    // _rels/.rels
    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rels.length, rels.codeUnits));

    // xl/_rels/workbook.xml.rels
    const workbookRels =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';
    archive.addFile(
      ArchiveFile(
        'xl/_rels/workbook.xml.rels',
        workbookRels.length,
        workbookRels.codeUnits,
      ),
    );

    // xl/workbook.xml
    const workbookXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';
    archive.addFile(
      ArchiveFile('xl/workbook.xml', workbookXml.length, workbookXml.codeUnits),
    );

    // xl/worksheets/sheet1.xml
    final sheet = workbook.activeSheet;
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    buffer.writeln('<sheetData>');

    int maxRow = 0;
    int maxCol = 0;
    for (final key in sheet.cells.keys) {
      final parts = key.split(',');
      if (parts.length == 2) {
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        if (r > maxRow) maxRow = r;
        if (c > maxCol) maxCol = c;
      }
    }

    for (int r = 0; r <= maxRow; r++) {
      buffer.writeln('<row r="${r + 1}">');
      for (int c = 0; c <= maxCol; c++) {
        final cell = sheet.cells['$r,$c'];
        final val = cell?.value?.toString() ?? '';
        if (val.isNotEmpty) {
          final colName = _getColName(c);
          buffer.writeln(
            '<c r="$colName${r + 1}" t="inlineStr"><is><t>${_escapeXml(val)}</t></is></c>',
          );
        }
      }
      buffer.writeln('</row>');
    }

    buffer.writeln('</sheetData>');
    buffer.writeln('</worksheet>');

    final sheet1Xml = buffer.toString();
    archive.addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        sheet1Xml.length,
        sheet1Xml.codeUnits,
      ),
    );

    final zipEncoder = ZipEncoder();
    final bytes = zipEncoder.encode(archive);
    return Uint8List.fromList(bytes!);
  }

  static String _getColName(int colIndex) {
    String name = '';
    while (colIndex >= 0) {
      name = String.fromCharCode(65 + (colIndex % 26)) + name;
      colIndex = (colIndex ~/ 26) - 1;
    }
    return name;
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
