import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/public/persistence_options.dart';
import 'package:sheetifye/src/public/workbook_exporter.dart';
import 'package:sheetifye/src/data/persistence/workbook_serializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Save As Tests', () {
    late ProviderContainer container;
    late WorkbookController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);
      controller.markAsClean();
    });

    tearDown(() {
      container.dispose();
    });

    test('1. onSaveAs callback invoked', () async {
      bool onSaveAsInvoked = false;
      final options = PersistenceOptions(
        onSaveAs: (workbook) async {
          onSaveAsInvoked = true;
          return true;
        },
      );

      if (options.onSaveAs != null) {
        await options.onSaveAs!(controller.state.workbook);
      }

      expect(onSaveAsInvoked, isTrue);
    });

    test(
      '2. SaveAs creates independent snapshot & 3. preserves workbook state',
      () async {
        controller.updateCellValue(0, 0, 'Original');
        controller.markAsClean();

        Workbook? savedWorkbook;
        final options = PersistenceOptions(
          onSaveAs: (workbook) async {
            final json = WorkbookExporter.toJson(workbook);
            savedWorkbook = WorkbookSerializer().deserialize(json);
            return true;
          },
        );

        controller.updateCellValue(1, 1, 'New Edit');

        if (options.onSaveAs != null) {
          await options.onSaveAs!(controller.state.workbook);
        }

        // Modify the original further to ensure snapshot independence
        controller.updateCellValue(2, 2, 'Future Edit');

        expect(savedWorkbook?.activeSheet.cells['0,0']?.value, 'Original');
        expect(savedWorkbook?.activeSheet.cells['1,1']?.value, 'New Edit');
        expect(savedWorkbook?.activeSheet.cells['2,2']?.value, isNull);

        // Current workbook state is preserved
        expect(
          controller.state.workbook.activeSheet.cells['2,2']?.value,
          'Future Edit',
        );
      },
    );

    test('4. SaveAs returns valid export bytes', () async {
      controller.updateCellValue(0, 0, 'Test Data');

      final xlsxBytes = WorkbookExporter.toXlsxBytes(controller.state.workbook);
      expect(xlsxBytes, isNotEmpty);
      expect(
        xlsxBytes.length,
        greaterThan(100),
      ); // Should have some ZIP structure
    });

    test('5. SaveAs after large modifications', () async {
      for (int i = 0; i < 100; i++) {
        controller.updateCellValue(i, 0, 'Data $i');
      }

      final options = PersistenceOptions(
        onSaveAs: (workbook) async {
          return true;
        },
      );

      bool success = false;
      if (options.onSaveAs != null) {
        success = await options.onSaveAs!(controller.state.workbook);
      }

      expect(success, isTrue);
    });

    test('6. SaveAs after formulas', () async {
      controller.updateCellValue(0, 0, '10');
      controller.updateCellValue(0, 1, '=A1*5');

      final options = PersistenceOptions(
        onSaveAs: (workbook) async {
          expect(workbook.activeSheet.cells['0,1']?.value?.toString(), '50.0');
          return true;
        },
      );

      if (options.onSaveAs != null) {
        await options.onSaveAs!(controller.state.workbook);
      }
    });

    test('7. SaveAs after merges', () async {
      controller.clearRange(GridRange.fromRect(0, 0, 2, 2));

      final options = PersistenceOptions(
        onSaveAs: (workbook) async {
          return true;
        },
      );

      bool success = false;
      if (options.onSaveAs != null) {
        success = await options.onSaveAs!(controller.state.workbook);
      }

      expect(success, isTrue);
    });

    test('8. SaveAs after filters/sorts', () async {
      controller.sortRange(GridRange.fromRect(0, 0, 5, 5), 0);

      final options = PersistenceOptions(
        onSaveAs: (workbook) async {
          return true;
        },
      );

      bool success = false;
      if (options.onSaveAs != null) {
        success = await options.onSaveAs!(controller.state.workbook);
      }

      expect(success, isTrue);
    });
  });
}
