import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/src/engine/clipboard/clipboard_manager.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-App Interoperability Engine Tests', () {
    late ClipboardManager clipboard;

    setUp(() {
      clipboard = ClipboardManager();
    });

    test('1. Excel TSV clipboard payload parsing', () {
      const excelTsv = 'Name\t"Notes"\n"A"\t"He said ""yes"""';
      final parsed = clipboard.parseTSV(excelTsv);

      expect(parsed.length, 2);
      expect(parsed[0][0], 'Name');
      expect(parsed[0][1], 'Notes');
      expect(parsed[1][0], 'A');
      expect(parsed[1][1], 'He said "yes"');
    });

    test('2. Google Sheets TSV clipboard payload parsing', () {
      const sheetsTsv = '100\t200\t"=A1+B1"\n"Line 1\nLine 2"\t"Hello"\t"Done"';
      final parsed = clipboard.parseTSV(sheetsTsv);

      expect(parsed.length, 2);
      expect(parsed[0][0], '100');
      expect(parsed[0][1], '200');
      expect(parsed[0][2], '=A1+B1');
      expect(parsed[1][0], 'Line 1\nLine 2');
    });

    test('3. Apple Numbers TSV clipboard payload parsing', () {
      const numbersTsv = 'Num1\tNum2\nVal1\tVal2';
      final parsed = clipboard.parseTSV(numbersTsv);
      expect(parsed.length, 2);
      expect(parsed[0][0], 'Num1');
      expect(parsed[1][0], 'Val1');
    });

    test(
      '4. Excel-generated CSV file parsing & 5. Google Sheets-generated CSV file parsing',
      () {
        const csv = 'ExcelCol1,"ExcelCol2\nRow2"\n"Escaped ""Quotes""",Value';
        final parsed = GridUtils.parseCSV(csv);

        expect(parsed.length, 2);
        expect(parsed[0][1], 'ExcelCol2\nRow2');
        expect(parsed[1][0], 'Escaped "Quotes"');
      },
    );

    test('6. Notepad/TextEdit tab-separated values parsing', () {
      const rawText = 'PlainCol1\tPlainCol2\nValue1\tValue2';
      final parsed = clipboard.parseTSV(rawText);
      expect(parsed.length, 2);
      expect(parsed[0][0], 'PlainCol1');
      expect(parsed[1][1], 'Value2');
    });

    test(
      '7. Sheetifye to Excel copy format & 8. Sheetifye to Google Sheets copy format',
      () {
        // Excel & Sheets expect double-quoted field escaping for special chars
        expect(clipboard.formatTSVField('Val,With,Commas'), 'Val,With,Commas');
        expect(clipboard.formatTSVField('Val"Quote'), '"Val""Quote"');
        expect(clipboard.formatTSVField('Val\nNewline'), '"Val\nNewline"');
      },
    );

    test('9. Cross-platform newline character mapping (\\r\\n vs \\n)', () {
      const windowsTsv = 'Col1\tCol2\r\nVal1\tVal2\r\n';
      final parsed = clipboard.parseTSV(windowsTsv);
      expect(parsed.length, 2);
      expect(parsed[0][0], 'Col1');
      expect(parsed[1][0], 'Val1');
    });

    test(
      '10. Interoperability recovery from poorly-formatted external app payloads',
      () {
        // Unclosed quote recoveries should handle parsing without crashing
        const malformedTsv = 'Col1\t"Unclosed quote\nRow2\tNormal';
        final parsed = clipboard.parseTSV(malformedTsv);
        expect(parsed.isNotEmpty, isTrue);
      },
    );
  });
}
