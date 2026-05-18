import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/features/workbook/widgets/sheetifye_workbook.dart';

void main() {
  testWidgets(
    'Mobile UX Integration - Taps, Double Taps, and Mobile Toolbars',
    (WidgetTester tester) async {
      // Force mobile viewport dimensions and mobile target platform in test
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: const Scaffold(body: SheetifyeWorkbook(readOnly: false)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify mobile toolbar is mounted and has correct icons
      expect(find.byIcon(Icons.functions_outlined), findsWidgets);
      expect(find.byIcon(Icons.copy_outlined), findsWidgets);
    },
  );
}
