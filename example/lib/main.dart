import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/sheetifye.dart';

/// Sheetifye Example Application
///
/// This minimal example demonstrates the core integration of the Sheetifye
/// spreadsheet engine into a Flutter application.
void main() {
  // Ensure Flutter bindings are initialized if needed (optional here)
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // 1. Sheetifye requires a [ProviderScope] at the root of your application
    // to manage the spreadsheet state efficiently.
    const ProviderScope(
      child: SheetifyeApp(),
    ),
  );
}

class SheetifyeApp extends StatelessWidget {
  const SheetifyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheetifye Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const SpreadsheetHome(),
    );
  }
}

class SpreadsheetHome extends StatelessWidget {
  const SpreadsheetHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 2. Simply drop the [Sheetifye] widget into your UI.
      // You can load data from assets, network, file, or memory.
      body: Sheetifye.network(
        'https://download.microsoft.com/download/5/B/2/5B2108F8-112B-4913-A761-38AFF2FD8598/Sample%20CSV%20file%20for%20importing%20contacts.csv',
        readOnly: false,

        // Optional: Customize the appearance to match your brand
        theme: SheetifyeThemeData.light().copyWith(
          primaryColor: Colors.blueAccent,
        ),

        // Persistence Lifecycle Callbacks
        onSave: (workbook) async {
          final messenger = ScaffoldMessenger.of(context);
          // Simulate a network save delay
          messenger.showSnackBar(
            const SnackBar(content: Text('Saving workbook...')),
          );
          await Future.delayed(const Duration(seconds: 1));
          messenger.showSnackBar(
            const SnackBar(content: Text('Workbook saved!')),
          );
          return true; // Mark as clean
        },
        onSaveAs: (workbook) async {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(content: Text('Saving as new workbook...')),
          );
          await Future.delayed(const Duration(seconds: 1));
          return true;
        },
        onDiscardChanges: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Changes discarded.')),
          );
        },
        onWorkbookChanged: (workbook, isDirty) {
          debugPrint('Workbook changed: ${workbook.name}, isDirty: $isDirty');
        },

        // Custom Developer Action
        customActions: [
          WorkbookAction(
            id: 'dev.print_stats',
            label: 'Print Workbook Stats',
            icon: Icons.analytics,
            group: WorkbookActionGroup.developer,
            onExecute: (context, ref) async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Developer Action Triggered!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
