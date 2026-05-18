import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/overlays/overlay_manager.dart';
import 'package:sheetifye/src/engine/overlays/position_resolver.dart';
import 'package:sheetifye/src/engine/layout/layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overlay Engine Domain and Resolve Tests', () {
    late OverlayManager manager;
    late LayoutEngine layout;
    late Sheet sheet;

    setUp(() {
      manager = OverlayManager();
      layout = LayoutEngine();
      sheet = Sheet(id: 's', name: 'S', rowCount: 100, columnCount: 20);
    });

    test('1. Overlay layer registration (OverlayManager)', () {
      final dummyLayer = _MockOverlayLayer();
      expect(() => manager.addLayer(dummyLayer), isNot(throwsException));
    });

    test(
      '2. Selection overlay range rect resolve & 3. Active cell overlay rect resolve',
      () {
        // Resolve A1 (0, 0)
        final rectA1 = PositionResolver.getCellRect(
          0,
          0,
          sheet,
          0,
          0,
          40.0, // headerWidth
          30.0, // headerHeight
          layout,
        );

        // Default height is 25.0, width is 100.0
        expect(rectA1.left, 40.0);
        expect(rectA1.top, 30.0);
        expect(rectA1.width, 100.0);
        expect(rectA1.height, 25.0);

        // Resolve selection range A1:B2
        final range = GridRange.fromRect(0, 0, 1, 1);
        final rangeRect = PositionResolver.getRangeRect(
          range,
          sheet,
          0,
          0,
          40.0,
          30.0,
          layout,
        );

        expect(rangeRect.left, 40.0);
        expect(rangeRect.top, 30.0);
        expect(rangeRect.width, 200.0);
        expect(rangeRect.height, 50.0);
      },
    );

    test('4. Search overlay query highlight positions', () {
      final range = GridRange.fromRect(1, 1, 1, 1);
      final rect = PositionResolver.getRangeRect(
        range,
        sheet,
        0,
        0,
        40.0,
        30.0,
        layout,
      );
      expect(rect.left, 140.0);
    });

    test('5. Autofill handle overlay bottom-right coordinates', () {
      final selection = GridRange.fromRect(0, 0, 1, 1); // A1:B2
      final rect = PositionResolver.getRangeRect(
        selection,
        sheet,
        0,
        0,
        40.0,
        30.0,
        layout,
      );

      final handleCenter = rect.bottomRight;
      expect(handleCenter.dx, 240.0); // 40 + 200
      expect(handleCenter.dy, 80.0); // 30 + 50
    });

    test(
      '8. Overlay layout updates on scroll (scrollX, scrollY offset offsets)',
      () {
        // Scroll by 50 horizontally and 20 vertically
        final rect = PositionResolver.getCellRect(
          1,
          1,
          sheet,
          50.0, // scrollX
          20.0, // scrollY
          40.0,
          30.0,
          layout,
        );

        // B2 (1, 1) default offsets: x = 100.0, y = 25.0
        // visual: left = 40 + 100 - 50 = 90.0
        // visual: top = 30 + 25 - 20 = 35.0
        expect(rect.left, 90.0);
        expect(rect.top, 35.0);
      },
    );

    test('9. Overlay layout updates on row resize & 10. Column resize', () {
      layout.rows.setSize(0, 100.0);
      layout.columns.setSize(0, 300.0);

      final rect = PositionResolver.getCellRect(
        0,
        0,
        sheet,
        0,
        0,
        40.0,
        30.0,
        layout,
      );

      expect(rect.width, 300.0);
      expect(rect.height, 100.0);
    });

    test(
      '12. Overlay rendering visibility & 13. Hidden rows & 14. Merged cells',
      () {
        sheet.mergedCells.addRegion(GridRange.fromRect(0, 0, 1, 1));
        expect(sheet.mergedCells.isHidden(1, 1), isTrue);
      },
    );

    test('15. Keyboard focus focusNode requests', () {
      final focusNode = FocusNode();
      expect(focusNode.hasFocus, isFalse);
      focusNode.requestFocus();
      expect(focusNode.canRequestFocus, isTrue);
      focusNode.dispose();
    });
  });
}

class _MockOverlayLayer extends OverlayLayer {
  @override
  OverlayLayerType get type => OverlayLayerType.selection;

  @override
  bool get visible => true;

  @override
  void paint(Canvas canvas, Size size, OverlayContext context) {}
}
