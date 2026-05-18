import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

/// A self-contained example demonstrating the core functionality of [Sheetifye].
///
/// This example shows how to:
/// 1. Wrap your application in a [ProviderScope].
/// 2. Load a spreadsheet from an asset.
/// 3. Provide a custom theme (optional).
void main() {
  runApp(
    const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SheetifyeDemo(),
      ),
    ),
  );
}

class SheetifyeDemo extends StatelessWidget {
  const SheetifyeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheetifye Standard Example'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Sheetifye.asset(
        'assets/restaurant_sales.xlsx',
        // Optional: Customise the theme to match your brand
        theme: SheetifyeThemeData.light().copyWith(
          primaryColor: Colors.blueAccent,
          selectionColor: Colors.blueAccent.withValues(alpha: 0.1),
        ),
        // Optional: Custom loading state
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
