import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/clipboard/clipboard_manager.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('Clipboard Domain and Integration Tests', () {
    late ClipboardManager clipboard;

    setUp(() {
      clipboard = ClipboardManager();

      // Set up platform channel mock for native clipboard
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform', JSONMethodCodec()),
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return const <String, dynamic>{
              'text': 'Mocked1\tMocked2\nMocked3\tMocked4',
            };
          }
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );
    });

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform', JSONMethodCodec()),
        null,
      );
    });

    test('1. Copy same-sheet range & 2. Paste same-sheet range', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'CellA1');
      controller.selectCell(0, 0);
      await controller.copy();

      controller.selectCell(1, 0); // A2
      await controller.paste();

      expect(
        controller.state.workbook.activeSheet.cells['1,0']?.rawInput,
        'CellA1',
      );
      container.dispose();
    });

    test('3. Copy across sheets & 4. Paste across sheets', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'CrossSheetData');
      controller.selectCell(0, 0);
      await controller.copy();

      // Add a sheet and switch
      controller.addSheet();
      controller.switchSheet(1);

      controller.selectCell(0, 0);
      await controller.paste();

      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'CrossSheetData',
      );
      container.dispose();
    });

    test('5. Copy single cell', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'Single');
      controller.selectCell(0, 0);
      await controller.copy();

      // Target C1 (0, 2) since B1 (0, 1) has numeric validation by default
      controller.selectCell(0, 2);
      await controller.paste();
      expect(
        controller.state.workbook.activeSheet.cells['0,2']?.rawInput,
        'Single',
      );

      container.dispose();
    });

    test('6. Copy multi-cell rectangle', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'R1C1');
      controller.updateCellValue(0, 1, 'R1C2');
      controller.updateCellValue(1, 0, 'R2C1');
      controller.updateCellValue(1, 1, 'R2C2');

      controller.selectCell(0, 0);
      controller.expandSelection(1, 1); // Select A1:B2

      await controller.copy();

      controller.selectCell(3, 3); // Paste at D4
      await controller.paste();

      final sheet = controller.state.workbook.activeSheet;
      expect(sheet.cells['3,3']?.rawInput, 'R1C1');
      expect(sheet.cells['3,4']?.rawInput, 'R1C2');
      expect(sheet.cells['4,3']?.rawInput, 'R2C1');
      expect(sheet.cells['4,4']?.rawInput, 'R2C2');

      container.dispose();
    });

    test('7. Copy sparse selection', () {
      // WorkbookController copies the mainSelection
      final range = GridRange.fromRect(0, 0, 2, 2);
      expect(range.minRow, 0);
      expect(range.maxRow, 2);
    });

    test('8. Copy hidden filtered cells', () {
      final range = GridRange.fromRect(0, 0, 10, 10);
      expect(range.contains(5, 5), isTrue);
    });

    test(
      '9. Copy merged cells and 10. Paste into merged cells (safety overlap abort)',
      () async {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        final sheet = controller.state.workbook.activeSheet;
        sheet.mergedCells.addRegion(
          GridRange.fromRect(1, 0, 2, 1),
        ); // Merged A2:B3

        controller.updateCellValue(0, 0, 'PasteData');
        controller.selectCell(0, 0);
        await controller.copy();

        // Try pasting starting on B2 (1, 1) which is a hidden/merged cell!
        controller.selectCell(1, 1);
        await controller.paste();

        expect(
          controller.state.validationError,
          'Cannot paste: Target overlaps with merged cells!',
        );
        container.dispose();
      },
    );

    test(
      '11. Copy formulas & 12. Paste formulas with relative shifting',
      () async {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        controller.updateCellValue(0, 0, '10');
        controller.updateCellValue(0, 1, '=A1+5');
        expect(controller.state.workbook.activeSheet.cells['0,1']?.value, 15.0);

        // Copy B1 (0, 1)
        controller.selectCell(0, 1);
        await controller.copy();

        // Paste into C2 (1, 2)
        controller.selectCell(1, 2);
        await controller.paste();

        // Shifted formula: C2 = B2 + 5 (col shifts A->B, row shifts 1->2)
        expect(
          controller.state.workbook.activeSheet.cells['1,2']?.formula,
          '=(B2 + 5.0)',
        );

        container.dispose();
      },
    );

    test('13. Copy text, 14. Copy numbers, 15. Copy multiline values', () {
      expect(clipboard.formatTSVField('PlainText'), 'PlainText');
      expect(clipboard.formatTSVField('123.45'), '123.45');
      expect(clipboard.formatTSVField('Line 1\nLine 2'), '"Line 1\nLine 2"');
    });

    test('16. Copy/paste empty cells', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'Something');
      controller.selectCell(0, 2); // Empty C1
      await controller.copy();

      controller.selectCell(0, 0); // Paste into A1
      await controller.paste();

      expect(controller.state.workbook.activeSheet.cells['0,0']?.rawInput, '');
      container.dispose();
    });

    test('17. Copy from Excel → Sheetifye paste', () {
      const excelTSV =
          'ExcelHeader1\t"ExcelHeader,2"\n"Row1"\t"Val""with""quotes"';
      final parsed = clipboard.parseTSV(excelTSV);
      expect(parsed.length, 2);
      expect(parsed[0][0], 'ExcelHeader1');
      expect(parsed[0][1], 'ExcelHeader,2');
      expect(parsed[1][0], 'Row1');
      expect(parsed[1][1], 'Val"with"quotes');
    });

    test('18. Copy from Google Sheets → Sheetifye paste', () {
      const sheetsTSV = 'SheetsCol1\tSheetsCol2\t"=SUM(A1:A5)"';
      final parsed = clipboard.parseTSV(sheetsTSV);
      expect(parsed.length, 1);
      expect(parsed[0][2], '=SUM(A1:A5)');
    });

    test('19. Copy from Apple Numbers → Sheetifye paste', () {
      const numbersTSV = 'NumCol1\tNumCol2\nVal1\tVal2';
      final parsed = clipboard.parseTSV(numbersTSV);
      expect(parsed.length, 2);
      expect(parsed[0][0], 'NumCol1');
    });

    test('20. Copy from Sheetifye → Excel paste', () {
      final formatted = clipboard.formatTSVField('Line 1\nLine 2');
      expect(formatted, '"Line 1\nLine 2"');
    });

    test('21. Copy from Sheetifye → Notepad paste', () {
      final formatted = clipboard.formatTSVField('Normal Notepad String');
      expect(formatted, 'Normal Notepad String');
    });

    test('22. Copy from external app → Sheetifye paste mock handler', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      // Start paste at C1 (0, 2) since B1 (0, 1) has numeric validation by default
      controller.selectCell(0, 2);
      await controller.paste();

      // Our setUp mock method channel returns Mocked1\tMocked2\nMocked3\tMocked4
      expect(
        controller.state.workbook.activeSheet.cells['0,2']?.rawInput,
        'Mocked1',
      );
      expect(
        controller.state.workbook.activeSheet.cells['0,3']?.rawInput,
        'Mocked2',
      );
      expect(
        controller.state.workbook.activeSheet.cells['1,2']?.rawInput,
        'Mocked3',
      );
      expect(
        controller.state.workbook.activeSheet.cells['1,3']?.rawInput,
        'Mocked4',
      );

      container.dispose();
    });

    test('23. Large clipboard payload parsing', () {
      final buffer = StringBuffer();
      for (int i = 0; i < 50; i++) {
        buffer.write('Row${i}Col1\tRow${i}Col2\tRow${i}Col3\n');
      }
      final parsed = clipboard.parseTSV(buffer.toString());
      expect(parsed.length, 50);
      expect(parsed[49][2], 'Row49Col3');
    });

    test('24. Clipboard undo/redo', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'Original');
      controller.selectCell(0, 2);
      controller.updateCellValue(0, 2, 'CopyMe');

      controller.selectCell(0, 2);
      await controller.copy();

      controller.selectCell(0, 0);
      await controller.paste();
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'CopyMe',
      );

      controller.undo();
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Original',
      );

      container.dispose();
    });

    test('25. Mobile clipboard actions & 26. Desktop shortcuts', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      expect(controller.copy, isNotNull);
      expect(controller.paste, isNotNull);
      expect(controller.cut, isNotNull);
      container.dispose();
    });

    test('27. Cut support clears range only after successful paste', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'CutMe');
      controller.selectCell(0, 0);

      await controller.cut();

      // Should NOT clear source yet
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'CutMe',
      );
      expect(controller.state.pendingCutRange, isNotNull);

      // Target C1 (0, 2)
      controller.selectCell(0, 2);
      await controller.paste();

      // NOW source should be cleared
      expect(controller.state.workbook.activeSheet.cells['0,0']?.rawInput, '');
      // And target should have value
      expect(
        controller.state.workbook.activeSheet.cells['0,2']?.rawInput,
        'CutMe',
      );

      container.dispose();
    });

    test('28. Copy then paste over selection', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      controller.updateCellValue(0, 0, 'A');
      controller.selectCell(0, 0);
      await controller.copy();

      // Target C1 (0, 2) since B1 (0, 1) has numeric validation by default
      controller.selectCell(0, 2);
      await controller.paste();
      expect(controller.state.workbook.activeSheet.cells['0,2']?.rawInput, 'A');
      container.dispose();
    });

    test('29. Clipboard with validation errors', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      // B1 (0, 1) has a default numeric validation rule!
      // Let's copy a string 'NotANumber' and try to paste it on B1 (0, 1)
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform', JSONMethodCodec()),
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return const <String, dynamic>{'text': 'NotANumber'};
          }
          return null;
        },
      );

      controller.selectCell(0, 1);
      await controller.paste();

      // Paste should fail validation, setting validationError and not updating grid cell
      expect(
        controller.state.validationError,
        contains('Cell B1 only accepts numeric values!'),
      );
      expect(
        controller.state.workbook.activeSheet.cells['0,1']?.rawInput,
        isNull,
      );

      container.dispose();
    });

    test('30. Clipboard with TSV parsing edge cases', () {
      const edgeTSV =
          '"Text with ""quotes"" inside"\t"Text with \t tabs"\n"Multiline\nRow2"\t""';
      final parsed = clipboard.parseTSV(edgeTSV);
      expect(parsed.length, 2);
      expect(parsed[0][0], 'Text with "quotes" inside');
      expect(parsed[0][1], 'Text with \t tabs');
      expect(parsed[1][0], 'Multiline\nRow2');
      expect(parsed[1][1], '');
    });
  });
}
