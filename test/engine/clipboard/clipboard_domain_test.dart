import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/clipboard/clipboard_manager.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('Clipboard Domain Tests', () {
    late ClipboardManager clipboard;
    late Sheet sheet;

    setUp(() {
      clipboard = ClipboardManager();
      sheet = Sheet(
        id: 'clip-sheet',
        name: 'Sheet1',
        rowCount: 10,
        columnCount: 10,
      );

      sheet.cells['0,0'] = const Cell(
        id: '0,0',
        row: 0,
        column: 0,
        value: 50,
        rawInput: '50',
      );
      sheet.cells['0,1'] = const Cell(
        id: '0,1',
        row: 0,
        column: 1,
        value: null,
        rawInput: '=A1*2',
        formula: '=A1*2',
      );

      // Set up platform channel mock for native clipboard
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform', JSONMethodCodec()),
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return const <String, dynamic>{'text': 'MockedVal1\tMockedVal2'};
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

    test(
      'Should parse RFC-4180 escaped TSV from standard clipboard systems',
      () {
        const text =
            '10\t"Hello\tTab"\t"Line1\nLine2"\n"He said ""ok"""\t20\t30';
        final parsed = clipboard.parseTSV(text);

        expect(parsed.length, 2);
        expect(parsed[0][0], '10');
        expect(parsed[0][1], 'Hello\tTab');
        expect(parsed[0][2], 'Line1\nLine2');
        expect(parsed[1][0], 'He said "ok"');
      },
    );

    test(
      'Should format and wrap cells containing tabs, quotes, or newlines',
      () {
        expect(clipboard.formatTSVField('Val'), 'Val');
        expect(clipboard.formatTSVField('Val1\tVal2'), '"Val1\tVal2"');
        expect(
          clipboard.formatTSVField('She said "yes"'),
          '"She said ""yes"""',
        );
      },
    );

    test(
      'WorkbookController paste should abort if overlaps with merged range',
      () async {
        final container = ProviderContainer();
        final controller = container.read(workbookProvider.notifier);
        controller.setReadOnly(false);

        // Create a merged region on A2:B3 (row 1, col 0 to row 2, col 1)
        final sheet = controller.state.workbook.activeSheet;
        sheet.mergedCells.addRegion(GridRange.fromRect(1, 0, 2, 1));

        // Attempt to paste starting at B2 (1, 1), which is a hidden/merged cell!
        controller.selectCell(1, 1);

        // Wait for paste completion (properly awaited)
        await controller.paste();

        // Should not corrupt grid layout and stays within safe validation error boundaries
        expect(
          controller.state.validationError,
          'Cannot paste: Target overlaps with merged cells!',
        );

        container.dispose();
      },
    );
  });
}
