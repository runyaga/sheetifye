import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/features/grid/widgets/sheet_grid.dart';

void main() {
  testWidgets('SheetGrid mounts successfully with painters and scrollbars', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SheetGrid())),
      ),
    );

    await tester.pumpAndSettle();

    // Verify raw scrollbars and viewport bounds exist
    expect(find.byType(RawScrollbar), findsWidgets);
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
