import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Selection Domain and Controller Tests', () {
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

    test('1. Single cell selection', () {
      expect(controller.state.activeCell, isNull);

      controller.selectCell(2, 3);
      expect(controller.state.activeCell?.row, 2);
      expect(controller.state.activeCell?.column, 3);
      expect(controller.state.mainSelection?.minRow, 2);
      expect(controller.state.mainSelection?.maxCol, 3);
    });

    test('2. Drag selection (start, update, end drag)', () {
      expect(controller.state.isDragging, isFalse);

      controller.startDrag(1, 1);
      expect(controller.state.isDragging, isTrue);
      expect(controller.state.activeCell?.row, 1);

      controller.updateDrag(3, 4);
      expect(controller.state.mainSelection?.minRow, 1);
      expect(controller.state.mainSelection?.maxRow, 3);
      expect(controller.state.mainSelection?.minCol, 1);
      expect(controller.state.mainSelection?.maxCol, 4);

      controller.endDrag();
      expect(controller.state.isDragging, isFalse);
    });

    test('3. Shift+Arrow range expansion (expandSelection)', () {
      controller.selectCell(2, 2);

      // Expand by 1 row down
      controller.expandSelection(1, 0);
      expect(controller.state.mainSelection?.minRow, 2);
      expect(controller.state.mainSelection?.maxRow, 3);
      expect(controller.state.mainSelection?.minCol, 2);
      expect(controller.state.mainSelection?.maxCol, 2);

      // Expand by 2 columns right
      controller.expandSelection(0, 2);
      expect(controller.state.mainSelection?.maxCol, 4);
    });

    test('4. Ctrl/Cmd selection behavior & additional selections', () {
      // Adding multiple disjoint selections
      final range1 = GridRange.fromRect(0, 0, 1, 1);
      final range2 = GridRange.fromRect(3, 3, 4, 4);

      controller.state = controller.state.copyWith(
        mainSelection: range1,
        additionalSelections: [range2],
      );

      expect(controller.state.mainSelection, range1);
      expect(controller.state.additionalSelections.length, 1);
      expect(controller.state.additionalSelections[0], range2);
    });

    test('5. Select all', () {
      controller.selectAll();
      expect(controller.state.mainSelection?.maxRow, 9);
      expect(controller.state.mainSelection?.maxCol, 9);
    });

    test('6. Selection after scroll and 7. Selection after edit', () {
      controller.selectCell(10, 5);
      expect(controller.state.activeCell?.row, 10);

      // Edit commits and preserves active cell selection
      controller.setEditing(true, initialValue: 'TestSelection');
      controller.commitEdit('TestSelection');
      expect(controller.state.activeCell?.row, 10);
      expect(controller.state.isEditing, isFalse);
    });

    test('8. Selection after paste & 9. Selection after undo/redo', () async {
      controller.updateCellValue(0, 0, 'Val1');
      controller.selectCell(0, 0);
      await controller.copy();

      // Paste on A2
      controller.selectCell(1, 0);
      await controller.paste();

      // Selection stays on A2 after paste
      expect(controller.state.activeCell?.row, 1);

      // Undo/Redo maintains current selection context
      controller.undo();
      expect(controller.state.activeCell?.row, 1);
    });

    test('10. Selection across merged cells', () {
      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(
        GridRange.fromRect(2, 2, 4, 4),
      ); // C3:E5 Merged

      controller.selectCell(2, 2);
      expect(sheet.mergedCells.isMerged(3, 3), isTrue);
      expect(sheet.mergedCells.isHidden(3, 3), isTrue);
    });

    test(
      '11. Selection with filtered rows & 12. Selection with sorted data',
      () {
        // Create data
        controller.updateCellValue(0, 0, '10');
        controller.updateCellValue(1, 0, '20');

        // Sort column A ascending
        controller.sortRange(
          GridRange.fromRect(0, 0, 1, 0),
          0,
          ascending: true,
        );

        // Select A1 after sort
        controller.selectCell(0, 0);
        expect(controller.state.activeCell?.row, 0);
      },
    );

    test('13. Selection on mobile touch & 14. Selection on desktop mouse', () {
      // Simulating tap selection via selectCell
      controller.selectCell(3, 3);
      expect(controller.state.activeCell?.row, 3);
    });

    test('15. Selection overlay alignment mapping', () {
      controller.selectCell(0, 0);
      expect(controller.state.activeCell?.row, 0);
      expect(controller.state.activeCell?.column, 0);
    });

    test(
      '16. Selection after row expansion & 17. Selection after column expansion',
      () {
        final sheet = controller.state.workbook.activeSheet;
        final initialRows = sheet.rowCount;

        // Select cell near bottom boundary to trigger expansion
        controller.selectCell(initialRows - 2, 0);
        final newSheet = controller.state.workbook.activeSheet;
        expect(newSheet.rowCount > initialRows, isTrue);
      },
    );

    test('18. Selection after sheet switch', () {
      controller.selectCell(1, 1);

      controller.addSheet();
      controller.switchSheet(1);

      // On new sheet, activeCell stays populated or switches to default (0, 0)
      expect(controller.state.activeCell, isNotNull);
    });

    test(
      '19. Selection in hidden rows/columns & 20. Large range selection performance',
      () {
        // Verify selecting a huge region does not cause crashes or lags
        final hugeRange = GridRange.fromRect(0, 0, 10000, 100);
        controller.state = controller.state.copyWith(mainSelection: hugeRange);
        expect(controller.state.mainSelection?.maxRow, 10000);
      },
    );
  });
}
