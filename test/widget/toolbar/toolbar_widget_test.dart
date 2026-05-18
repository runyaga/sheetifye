import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/features/toolbar/widgets/sheetifye_toolbar.dart';

void main() {
  testWidgets(
    'SheetifyeToolbar displays title and search icon, toggles input field',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      final controller = container.read(workbookProvider.notifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: SheetifyeToolbar(controller: controller)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify search icon is present
      final searchFinder = find.byIcon(Icons.search);
      expect(searchFinder, findsOneWidget);

      // Tap search to open search field
      await tester.tap(searchFinder);
      await tester.pumpAndSettle();

      // Verify textfield mounts
      expect(find.byType(TextField), findsOneWidget);

      container.dispose();
    },
  );
}
