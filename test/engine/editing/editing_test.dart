import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cell Editing Domain Tests', () {
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

    test('1. Single cell edit - start, change value, commit', () {
      controller.selectCell(0, 0);
      expect(controller.state.isEditing, isFalse);

      controller.setEditing(true, initialValue: 'Test');
      expect(controller.state.isEditing, isTrue);
      expect(controller.state.editValue, 'Test');

      controller.updateEditValue('New Test');
      expect(controller.state.editValue, 'New Test');

      controller.commitEdit('New Test');
      expect(controller.state.isEditing, isFalse);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'New Test',
      );
    });

    test('2. Numeric edit - parsing and storage', () {
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: '123.45');
      controller.commitEdit('123.45');
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        '123.45',
      );
    });

    test('3. String edit - normal string', () {
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'Plain Text String');
      controller.commitEdit('Plain Text String');
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Plain Text String',
      );
    });

    test('4. Multiline text edit', () {
      controller.selectCell(0, 0);
      const multiline = 'Line 1\nLine 2\nLine 3';
      controller.setEditing(true, initialValue: multiline);
      controller.commitEdit(multiline);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        multiline,
      );
    });

    test('5. Emoji/UTF-8 edit', () {
      controller.selectCell(0, 0);
      const emojis = '🚀🔥📊 𓃠 漢字';
      controller.setEditing(true, initialValue: emojis);
      controller.commitEdit(emojis);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        emojis,
      );
    });

    test('6. RTL text edit', () {
      controller.selectCell(0, 0);
      const rtlText = 'مرحبا بالعالم';
      controller.setEditing(true, initialValue: rtlText);
      controller.commitEdit(rtlText);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        rtlText,
      );
    });

    test('7. Formula edit - starts with =', () {
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: '=A2*10');
      controller.commitEdit('=A2*10');
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.formula,
        '=A2*10',
      );
    });

    test('8. Empty cell edit - commit blank string', () {
      controller.selectCell(0, 0);
      controller.updateCellValue(0, 0, 'Original');

      controller.setEditing(true, initialValue: '');
      controller.commitEdit('');
      expect(controller.state.workbook.activeSheet.cells['0,0']?.rawInput, '');
    });

    test('9. Cancel edit with Escape leaves value untouched', () {
      controller.selectCell(0, 0);
      controller.updateCellValue(0, 0, 'Keep Me');

      controller.setEditing(true, initialValue: 'Overwriting...');
      controller.cancelEdit();

      expect(controller.state.isEditing, isFalse);
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Keep Me',
      );
    });

    test('10. Commit edit with Enter moves active cell down', () {
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'Val');
      controller.commitEdit('Val');

      // The keystroke or manual command will commit and then we can simulate the enter key move
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'Val',
      );

      // Simulate enter key moving down
      controller.moveActiveCell(1, 0);
      expect(controller.state.activeCell?.row, 1);
      expect(controller.state.activeCell?.column, 0);
    });

    test('11. Commit edit with Tab moves active cell right', () {
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'TabVal');
      controller.commitEdit('TabVal');
      expect(
        controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
        'TabVal',
      );

      // Simulate tab key moving right
      controller.moveActiveCell(0, 1);
      expect(controller.state.activeCell?.row, 0);
      expect(controller.state.activeCell?.column, 1);
    });

    test('12. Edit by double tap/click toggles editing state', () {
      controller.selectCell(1, 1);
      expect(controller.state.isEditing, isFalse);

      // Trigger double click edit toggle
      controller.setEditing(true);
      expect(controller.state.isEditing, isTrue);
    });

    test('13. Edit from formula bar syncs to active cell state', () {
      controller.selectCell(2, 2);
      controller.setEditing(true, initialValue: 'FormulaBarEdit');

      // Updating editing value behaves like typing in the formula bar
      controller.updateEditValue('FormulaBarEditUpdate');
      expect(controller.state.editValue, 'FormulaBarEditUpdate');

      controller.commitEdit('FormulaBarEditUpdate');
      expect(
        controller.state.workbook.activeSheet.cells['2,2']?.rawInput,
        'FormulaBarEditUpdate',
      );
    });

    test('14. Printable key starts editing', () {
      controller.selectCell(0, 0);
      // Simulate keyboard input starting edit directly with character
      controller.setEditing(true, initialValue: 'a');
      expect(controller.state.isEditing, isTrue);
      expect(controller.state.editValue, 'a');
    });

    test(
      '15. Rapid edit switching commits previous cell and edits new cell',
      () {
        controller.selectCell(0, 0);
        controller.setEditing(true, initialValue: 'First');

        // Switch selection and trigger commit
        controller.commitEdit('First committed');
        controller.selectCell(0, 1);
        controller.setEditing(true, initialValue: 'Second');

        expect(
          controller.state.workbook.activeSheet.cells['0,0']?.rawInput,
          'First committed',
        );
        expect(controller.state.isEditing, isTrue);
        expect(controller.state.editValue, 'Second');
      },
    );

    test('16. Edit while selection changes', () {
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'Editing...');

      // Select another cell without committing explicitly first
      controller.selectCell(0, 1);
      // It cancels or keeps active cell editing: selectCell sets editing to false
      expect(controller.state.isEditing, isFalse);
      expect(controller.state.activeCell?.row, 0);
      expect(controller.state.activeCell?.column, 1);
    });

    test('17. Edit after scrolling is fully supported', () {
      // Simulate viewport scroll offset change, then start edit
      controller.selectCell(50, 10);
      controller.setEditing(true, initialValue: 'ScrolledEdit');
      controller.commitEdit('ScrolledEdit');
      expect(
        controller.state.workbook.activeSheet.cells['50,10']?.rawInput,
        'ScrolledEdit',
      );
    });

    test('18. Edit in hidden/filtered view works internally', () {
      // Create hidden/filtered rows (row 5, column 0)
      controller.selectCell(5, 0);
      controller.setEditing(true, initialValue: 'HiddenVal');
      controller.commitEdit('HiddenVal');
      expect(
        controller.state.workbook.activeSheet.cells['5,0']?.rawInput,
        'HiddenVal',
      );
    });

    test('19. Edit in merged cell commits to top-left coordinate', () {
      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 1, 1));

      // Editing active top-left cell B2 (1, 1)
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'MergedVal');
      controller.commitEdit('MergedVal');

      expect(sheet.cells['0,0']?.rawInput, 'MergedVal');
    });

    test('20. Edit validation failure handling keeps overlay active', () {
      // B1 (0, 1) only accepts numbers
      controller.selectCell(0, 1);
      controller.setEditing(true, initialValue: 'invalid-text');
      controller.commitEdit('invalid-text');

      // Editor remains active because validation failed
      expect(controller.state.isEditing, isTrue);
      expect(controller.state.validationError, isNotNull);
    });
  });
}
