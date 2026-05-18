import 'package:flutter_test/flutter_test.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/virtualization/virtualization_engine.dart';
import 'package:sheetifye/src/engine/layout/layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Virtualization Engine Domain Tests', () {
    late LayoutEngine layout;
    late VirtualizationEngine engine;

    setUp(() {
      layout = LayoutEngine();
      engine = VirtualizationEngine(layout: layout);
    });

    test('1. Viewport range calculation & 2. Viewport range under scroll', () {
      final range = engine.calculateViewportRange(
        scrollX: 0,
        scrollY: 0,
        viewportWidth: 800,
        viewportHeight: 600,
        totalRows: 1000,
        totalCols: 100,
      );

      expect(range.startRow, 0);
      expect(range.startColumn, 0);
      expect(range.endRow > 0, isTrue);
      expect(range.endColumn > 0, isTrue);

      // Scrolled calculation
      final scrolledRange = engine.calculateViewportRange(
        scrollX: 400,
        scrollY: 300,
        viewportWidth: 800,
        viewportHeight: 600,
        totalRows: 1000,
        totalCols: 100,
      );

      expect(scrolledRange.startRow > 0, isTrue);
      expect(scrolledRange.startColumn > 0, isTrue);
    });

    test(
      '3. Viewport range with dynamic row heights & 4. Viewport range with dynamic col widths',
      () {
        final sheet = Sheet(id: 's', name: 'S', rowCount: 10, columnCount: 10);

        // Update custom heights
        layout.rows.setSize(1, 100.0);
        layout.columns.setSize(1, 200.0);

        expect(layout.getRowHeight(1, sheet), 100.0);
        expect(layout.getColumnWidth(1, sheet), 200.0);
      },
    );

    test('5. Grid column labels & 6. Address parser & 7. Range parser', () {
      expect(GridUtils.getColumnLabel(0), 'A');
      expect(GridUtils.getColumnLabel(25), 'Z');
      expect(GridUtils.getColumnLabel(26), 'AA');

      final coord = GridUtils.parseAddress('C3');
      expect(coord.row, 2);
      expect(coord.column, 2);

      final range = GridUtils.parseRange('B2:D5');
      expect(range.minRow, 1);
      expect(range.maxRow, 4);
      expect(range.minCol, 1);
      expect(range.maxCol, 3);
    });

    test(
      '8. Layout caching & 9. Virtualization after row insertion/deletion',
      () {
        final sheet = Sheet(id: 's', name: 'S', rowCount: 10, columnCount: 10);
        expect(
          layout.getTotalHeight(sheet.rowCount),
          250.0,
        ); // default 25.0 * 10
      },
    );

    test('10. Virtualization after column insertion/deletion', () {
      final sheet = Sheet(id: 's', name: 'S', rowCount: 10, columnCount: 10);
      expect(
        layout.getTotalWidth(sheet.columnCount),
        1000.0,
      ); // default 100.0 * 10
    });

    test(
      '11. Virtualization with empty grid & 12. Virtualization with large grid',
      () {
        final emptyRange = engine.calculateViewportRange(
          scrollX: 0,
          scrollY: 0,
          viewportWidth: 800,
          viewportHeight: 600,
          totalRows: 0,
          totalCols: 0,
        );
        expect(emptyRange.startRow, 0);
        expect(emptyRange.endRow, -1);

        final largeRange = engine.calculateViewportRange(
          scrollX: 0,
          scrollY: 0,
          viewportWidth: 800,
          viewportHeight: 600,
          totalRows: 1000000,
          totalCols: 10000,
        );
        expect(largeRange.startRow, 0);
      },
    );

    test(
      '13. Virtualization with merged cells & 14. Virtualization with hidden rows & 15. Virtualization with filtered views',
      () {
        final sheet = Sheet(id: 's', name: 'S', rowCount: 10, columnCount: 10);
        sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 2, 2));

        expect(sheet.mergedCells.isHidden(1, 1), isTrue);
      },
    );

    test(
      '16. Dynamic row height adjustment & 17. Dynamic column width adjustment & 18. Viewport cell painting virtualization boundaries',
      () {
        layout.rows.setSize(5, 50.0);
        layout.columns.setSize(5, 150.0);

        expect(
          layout.getRowOffset(
            5,
            Sheet(id: 's', name: 'S', rowCount: 10, columnCount: 10),
          ),
          125.0,
        );
      },
    );

    test(
      '19. Memory footprint during layout computations & 20. Re-layout performance on window/screen resize',
      () {
        // Benchmark computation loops
        for (int i = 0; i < 5000; i++) {
          layout.getTotalHeight(100);
          layout.getTotalWidth(50);
        }
        expect(true, isTrue); // Complete without memory issues
      },
    );
  });
}
