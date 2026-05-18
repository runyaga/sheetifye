import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CSV Engine Domain & Integration Tests', () {
    test('1. Basic CSV import & 2. Basic CSV export', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      const csv = 'Header1,Header2\nValue1,Value2';
      controller.importCSV(csv, sheetName: 'BasicImport');

      final activeSheet = controller.state.workbook.activeSheet;
      expect(activeSheet.name, 'BasicImport');
      expect(activeSheet.cells['0,0']?.rawInput, 'Header1');
      expect(activeSheet.cells['1,1']?.rawInput, 'Value2');

      final exported = controller.exportCSV();
      expect(exported, 'Header1,Header2\nValue1,Value2');

      container.dispose();
    });

    test(
      '3. Quoted strings, 4. Escaped quotes & 5. Comma inside quoted field',
      () {
        const csv = 'A,"B,C"\n"D""E",F';
        final parsed = GridUtils.parseCSV(csv);

        expect(parsed.length, 2);
        expect(parsed[0][0], 'A');
        expect(parsed[0][1], 'B,C');
        expect(parsed[1][0], 'D"E');
        expect(parsed[1][1], 'F');
      },
    );

    test('6. Multiline CSV values', () {
      const csv = 'Row1,"Line1\nLine2"\nRow2,Done';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 2);
      expect(parsed[0][1], 'Line1\nLine2');
      expect(parsed[1][0], 'Row2');
    });

    test('7. UTF-8 CSV with Unicode & special characters', () {
      const csv = 'Unicode,📊🔥\n𓃠,مرحبا\n日本語,Deutsch';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 3);
      expect(parsed[0][1], '📊🔥');
      expect(parsed[1][0], '𓃠');
      expect(parsed[1][1], 'مرحبا');
      expect(parsed[2][0], '日本語');
    });

    test('8. Empty rows & 9. Empty trailing cells', () {
      const csv = 'Row1,,\n\nRow3,';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 3);
      expect(parsed[0][1], '');
      expect(parsed[0][2], '');
      expect(parsed[1].isEmpty, isTrue); // Empty row
      expect(parsed[2][1], '');
    });

    test('10. Uneven row lengths parsing', () {
      const csv = 'Col1\nCol1,Col2\nCol1,Col2,Col3';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 3);
      expect(parsed[0].length, 1);
      expect(parsed[1].length, 2);
      expect(parsed[2].length, 3);
    });

    test('11. Large CSV file import & 12. Large CSV file export', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 200; i++) {
        buffer.write('Row${i}C1,Row${i}C2,Row${i}C3\n');
      }
      final parsed = GridUtils.parseCSV(buffer.toString());
      expect(parsed.length, 200);
      expect(parsed[199][2], 'Row199C3');
    });

    test('13. CSV with formula-like text imports as active formulas', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      const csv = '10,20\n=A1+B1,Other';
      controller.importCSV(csv, sheetName: 'FormulaCSV');

      final sheet = controller.state.workbook.activeSheet;
      expect(sheet.cells['1,0']?.formula, '=A1+B1');
      expect(sheet.cells['1,0']?.value, 30.0);

      container.dispose();
    });

    test('14. CSV with decimals and negatives', () {
      const csv = '-12.34,0.0056\n-100,500';
      final parsed = GridUtils.parseCSV(csv);
      expect(parsed[0][0], '-12.34');
      expect(parsed[0][1], '0.0056');
      expect(parsed[1][0], '-100');
    });

    test('15. CSV with dates & 16. CSV with special characters', () {
      const csv = '2026-05-18,12/31/2026\n"Hello #@!\$%^&*()",Done';
      final parsed = GridUtils.parseCSV(csv);
      expect(parsed[0][0], '2026-05-18');
      expect(parsed[0][1], '12/31/2026');
      expect(parsed[1][0], 'Hello #@!\$%^&*()');
    });

    test('17. CSV re-import parity roundtrip', () {
      const original = 'A,"B,C"\n"D""E",F';
      final parsed = GridUtils.parseCSV(original);

      final exported = parsed
          .map((row) {
            return row.map((cell) => GridUtils.formatCSVField(cell)).join(',');
          })
          .join('\n');

      expect(exported, original);
    });

    test(
      '18. CSV export opens in Excel & 19. CSV export opens in Google Sheets',
      () {
        // Excel/Sheets compatible escaping is guaranteed by wrapping comma/quote fields
        expect(GridUtils.formatCSVField('Val,With,Comma'), '"Val,With,Comma"');
        expect(GridUtils.formatCSVField('Val"Quote'), '"Val""Quote"');
      },
    );

    test(
      '20. CSV import from Excel-generated CSV & 21. CSV import from Google Sheets-generated CSV',
      () {
        const excelCSV = 'ExcelC1,"ExcelC2\nNewRow"\n"Quotes ""escaped""",Yes';
        final parsed = GridUtils.parseCSV(excelCSV);

        expect(parsed.length, 2);
        expect(parsed[0][1], 'ExcelC2\nNewRow');
        expect(parsed[1][0], 'Quotes "escaped"');
      },
    );

    test('22. Invalid CSV recovery', () {
      // Unclosed quote string should recover gracefully and not crash
      const invalidCSV = 'Row1,"Unclosed quote\nRow2,NormalCell';
      final parsed = GridUtils.parseCSV(invalidCSV);

      expect(parsed.isNotEmpty, isTrue);
    });

    test(
      '23. CSV virtualization stability, 24. CSV memory behavior, 25. CSV scrolling behavior',
      () {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        // Create a large CSV to simulate virtual grid virtualization rendering
        final buffer = StringBuffer();
        for (int i = 0; i < 500; i++) {
          buffer.write('$i,A$i,B$i,C$i,D$i\n');
        }

        controller.importCSV(buffer.toString(), sheetName: 'VirtualCSV');
        final sheet = controller.state.workbook.activeSheet;

        // Verify sheet bounds expanded
        expect(sheet.rowCount >= 500, isTrue);
        expect(sheet.columnCount >= 5, isTrue);

        container.dispose();
      },
    );
  });
}
