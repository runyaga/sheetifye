import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CSV Domain Tests', () {
    test('Should parse commas inside quoted CSV cell contents correctly', () {
      const csv = 'Header1,"Header,2",Header3';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 1);
      expect(parsed[0][0], 'Header1');
      expect(parsed[0][1], 'Header,2');
      expect(parsed[0][2], 'Header3');
    });

    test('Should parse multiline quoted cells and escaped quotes', () {
      const csv = '10,"He said ""hello"""\n"Line1\nLine2",20';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 2);
      expect(parsed[0][0], '10');
      expect(parsed[0][1], 'He said "hello"');
      expect(parsed[1][0], 'Line1\nLine2');
      expect(parsed[1][1], '20');
    });

    test('Should handle uneven row lengths and trailing blank columns', () {
      const csv = 'A,B\nC,D,E\nF';
      final parsed = GridUtils.parseCSV(csv);

      expect(parsed.length, 3);
      expect(parsed[0].length, 2);
      expect(parsed[1].length, 3);
      expect(parsed[2].length, 1);
    });

    test('Should verify CSV export-to-import parity roundtrip precisely', () {
      const input = 'A,"B,C"\n"D""E",F';
      final parsed = GridUtils.parseCSV(input);

      // Re-export
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < parsed.length; i++) {
        final row = parsed[i];
        final escapedRow = row
            .map((cell) => GridUtils.formatCSVField(cell))
            .join(',');
        buffer.write(escapedRow);
        if (i < parsed.length - 1) {
          buffer.write('\n');
        }
      }

      // Parity check
      expect(buffer.toString(), input);
    });
  });
}
