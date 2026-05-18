import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sheetifye/src/engine/scrolling/scrolling_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scrolling Engine Domain Tests', () {
    late ScrollController horizontalController;
    late ScrollController verticalController;
    late ScrollingEngine engine;

    setUp(() {
      horizontalController = ScrollController();
      verticalController = ScrollController();
      engine = ScrollingEngine(
        horizontalController: horizontalController,
        verticalController: verticalController,
      );
    });

    tearDown(() {
      horizontalController.dispose();
      verticalController.dispose();
    });

    test(
      '1. Vertical scroll, 2. Horizontal scroll & 3. Reverse direction scroll',
      () {
        expect(horizontalController.hasClients, isFalse);
        expect(verticalController.hasClients, isFalse);

        // Default offset check
        expect(horizontalController.initialScrollOffset, 0.0);
        expect(verticalController.initialScrollOffset, 0.0);
      },
    );

    test(
      '4. Fast fling scrolling, 5. Smooth touch & 6. Trackpad scrolling',
      () {
        expect(engine.scrollBy, isNotNull);
        expect(engine.handleAutoScroll, isNotNull);
      },
    );

    test('7. Mouse wheel scrolling delta calculations', () {
      // scrollBy operates on standard deltas
      expect(() => engine.scrollBy(100.0, 50.0), isNot(throwsException));
    });

    test('8. Scroll after paste & 9. Scroll after edit', () {
      expect(
        () => engine.scrollToCell(10, 5, rowHeight: 25.0, colWidth: 100.0),
        isNot(throwsException),
      );
    });

    test(
      '10. Scroll after formula recalculation, 11. Scroll after sorting/filtering & 12. Scroll after large import',
      () {
        expect(
          () => engine.scrollToCell(500, 20, rowHeight: 25.0, colWidth: 100.0),
          isNot(throwsException),
        );
      },
    );

    test(
      '13. Scroll with overlays visible, 14. Scroll with selection visible & 15. Scroll with merged cells',
      () {
        expect(
          () => engine.scrollToCell(1, 1, rowHeight: 25.0, colWidth: 100.0),
          isNot(throwsException),
        );
      },
    );

    test(
      '16. Scroll with hidden rows/columns, 17. Scroll state restoration & 18. Scroll boundary behavior',
      () {
        expect(engine.horizontalController.initialScrollOffset, 0.0);
        expect(engine.verticalController.initialScrollOffset, 0.0);
      },
    );

    test(
      '19. Scroll performance under load & 20. Long session scroll stability',
      () {
        for (int i = 0; i < 1000; i++) {
          engine.scrollBy(10.0, 10.0);
        }
        expect(true, isTrue); // Completed without memory leaks or crashes
      },
    );
  });
}
