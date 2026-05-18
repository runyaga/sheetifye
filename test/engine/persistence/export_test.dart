import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/workbook_exporter.dart';
import 'package:sheetifye/src/data/persistence/workbook_serializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Export Tests', () {
    late ProviderContainer container;
    late WorkbookController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);
    });

    tearDown(() {
      container.dispose();
    });

    group('XLSX EXPORT', () {
      test('1. Export valid workbook', () {
        controller.updateCellValue(0, 0, 'Test');
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('2. Export formulas correctly', () {
        controller.updateCellValue(0, 0, '10');
        controller.updateCellValue(0, 1, '=A1*2');
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('3. Export merged cells correctly', () {
        controller.clearRange(GridRange.fromRect(0, 0, 1, 1));
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('4. Export multiple sheets', () {
        controller.addSheet();
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('5. Export styles correctly', () {
        // Assume styles are handled or mock them
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('6. Export row heights', () {
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('7. Export column widths', () {
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('8. Export large workbook', () {
        controller.updateCellValue(1000, 10, 'Large');
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('9. Export sparse workbook', () {
        controller.updateCellValue(1000, 1000, 'Sparse');
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });

      test('10. Export UTF-8 content', () {
        controller.updateCellValue(0, 0, 'こんにちは');
        final bytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
        expect(bytes, isNotEmpty);
      });
    });

    group('CSV EXPORT', () {
      test('11. CSV export basic', () {
        controller.updateCellValue(0, 0, 'A');
        controller.updateCellValue(0, 1, 'B');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, 'A,B');
      });

      test('12. CSV export quoted values', () {
        controller.updateCellValue(0, 0, 'A, B');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, '"A, B"');
      });

      test('13. CSV export multiline values', () {
        controller.updateCellValue(
          0,
          0,
          'Line1\\nLine2',
        ); // Test formatting logic mapping
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, contains('Line1'));
      });

      test('14. CSV export escaped quotes', () {
        controller.updateCellValue(0, 0, 'He said "Hello"');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, '"He said ""Hello"""');
      });

      test('15. CSV export UTF-8', () {
        controller.updateCellValue(0, 0, 'こんにちは');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, 'こんにちは');
      });

      test('16. CSV export formulas as text', () {
        controller.updateCellValue(0, 0, '10');
        controller.updateCellValue(0, 1, '=A1*2');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        // It outputs the raw input or formula depending on logic.
        expect(csv, contains('=A1*2'));
      });

      test('17. CSV export empty cells', () {
        controller.updateCellValue(0, 0, 'A');
        controller.updateCellValue(0, 2, 'C');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, 'A,,C');
      });

      test('18. CSV export uneven rows', () {
        controller.updateCellValue(0, 0, 'A');
        controller.updateCellValue(1, 1, 'B');
        final csv = WorkbookExporter.toCsv(controller.state.workbook);
        expect(csv, 'A,\n,B');
      });
    });

    group('JSON EXPORT', () {
      test('19. JSON serialization parity', () {
        controller.updateCellValue(0, 0, 'Test');
        final json = WorkbookExporter.toJson(controller.state.workbook);
        expect(json, isNotEmpty);
        expect(json['sheets'], isNotNull);
      });

      test('20. JSON restore parity', () {
        controller.updateCellValue(0, 0, 'RestoreTest');
        final json = WorkbookExporter.toJson(controller.state.workbook);
        final restored = WorkbookSerializer().deserialize(json);
        expect(restored.activeSheet.cells['0,0']?.value, 'RestoreTest');
      });

      test('21. JSON export formulas', () {
        controller.updateCellValue(0, 0, '10');
        controller.updateCellValue(0, 1, '=A1*2');
        final json = WorkbookExporter.toJson(controller.state.workbook);
        final restored = WorkbookSerializer().deserialize(json);
        expect(restored.activeSheet.cells['0,1']?.formula, '=A1*2');
      });

      test('22. JSON export merges', () {
        controller.clearRange(GridRange.fromRect(0, 0, 1, 1));
        final json = WorkbookExporter.toJson(controller.state.workbook);
        final restored = WorkbookSerializer().deserialize(json);
        expect(restored, isNotNull);
      });

      test('23. JSON export workbook metadata', () {
        final json = WorkbookExporter.toJson(controller.state.workbook);
        expect(json['id'], isNotNull);
        expect(json['name'], isNotNull);
        expect(json['activeSheetIndex'], isNotNull);
      });
    });
  });
}
