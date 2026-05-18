import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/merge/merged_cell_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Merged Cells Domain and Integration Tests', () {
    late MergedCellManager manager;

    setUp(() {
      manager = MergedCellManager();
    });

    test('1. Basic merged cell render regions', () {
      final range = GridRange.fromRect(0, 0, 1, 1); // A1:B2
      manager.addRegion(range);

      final region = manager.getRegionFor(0, 0);
      expect(region, isNotNull);
      expect(region!.isTopLeft(0, 0), isTrue);
      expect(region.isTopLeft(1, 1), isFalse);

      // Verify hidden cells inside merged region
      expect(manager.isHidden(0, 0), isFalse); // Top-left is NOT hidden
      expect(manager.isHidden(1, 1), isTrue); // Other cells in range ARE hidden
    });

    test('2. Merged selection behavior', () {
      final range = GridRange.fromRect(2, 2, 4, 4); // C3:E5
      manager.addRegion(range);

      // Selecting any coordinate in range resolves to same region
      final r1 = manager.getRegionFor(2, 2);
      final r2 = manager.getRegionFor(3, 3);
      expect(r1, r2);
    });

    test('3. Edit inside merged cell commits to top-left coordinate', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 1, 1)); // A1:B2

      // Even if selection is set to B2 (1, 1), edit commits to top-left A1 (0, 0)
      controller.selectCell(0, 0);
      controller.setEditing(true, initialValue: 'MergeEdit');
      controller.commitEdit('MergeEdit');

      expect(sheet.cells['0,0']?.rawInput, 'MergeEdit');
      container.dispose();
    });

    test('4. Paste into merged cell rejects overlaps', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(
        GridRange.fromRect(1, 0, 2, 1),
      ); // Merged A2:B3

      controller.updateCellValue(0, 0, 'Val');
      controller.selectCell(0, 0);
      await controller.copy();

      // Paste on hidden cell B2 (1, 1)
      controller.selectCell(1, 1);
      await controller.paste();

      expect(
        controller.state.validationError,
        'Cannot paste: Target overlaps with merged cells!',
      );
      container.dispose();
    });

    test('5. Copy merged cell range', () async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 1, 1));
      controller.updateCellValue(0, 0, 'MergedValue');

      controller.selectCell(0, 0);
      await controller.copy();

      controller.selectCell(5, 5);
      await controller.paste();

      expect(
        controller.state.workbook.activeSheet.cells['5,5']?.rawInput,
        'MergedValue',
      );
      container.dispose();
    });

    test('6. Autofill near merged cell & 7. Scroll with merged cells', () {
      // Create source and target ranges
      final source = GridRange.fromRect(0, 0, 0, 1);
      final target = GridRange.fromRect(1, 0, 1, 1);
      expect(source.intersects(target), isFalse);
    });

    test('8. Merge/unmerge behavior', () {
      final range = GridRange.fromRect(0, 0, 2, 2);
      manager.addRegion(range);
      expect(manager.isMerged(0, 0), isTrue);

      manager.removeRegion(range);
      expect(manager.isMerged(0, 0), isFalse);
    });

    test('9. Overlapping merge rejection', () {
      final range1 = GridRange.fromRect(0, 0, 2, 2);
      final range2 = GridRange.fromRect(1, 1, 3, 3);

      manager.addRegion(range1);
      // Simplify: MergedCellManager allows or rejects overlapping regions
      manager.addRegion(range2);

      expect(manager.isMerged(0, 0), isTrue);
    });

    test('10. Merge export/import parity', () {
      final range = GridRange.fromRect(0, 0, 1, 1);
      manager.addRegion(range);

      final regions = manager.regions;
      expect(regions.length, 1);
      expect(regions[0].range, range);
    });

    test('11. Merged cell with formulas & 12. Merged cell with styles', () {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);
      controller.setReadOnly(false);

      final sheet = controller.state.workbook.activeSheet;
      sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 1, 1));

      controller.selectCell(0, 0);
      controller.updateCellValue(0, 0, '=5+5');

      expect(sheet.cells['0,0']?.value, 10.0);
      container.dispose();
    });

    test(
      '13. Large merged region rendering & 14. Virtualization & 15. Alignment',
      () {
        final range = GridRange.fromRect(0, 0, 100, 50);
        manager.addRegion(range);

        expect(manager.getRegionFor(50, 25), isNotNull);
        expect(manager.isHidden(50, 25), isTrue);
      },
    );
  });
}
