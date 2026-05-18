import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/features/actions/models/workbook_action.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';
import 'package:sheetifye/src/public/persistence_options.dart';
import 'package:sheetifye/src/public/workbook_exporter.dart';
import 'package:flutter/services.dart';

final workbookActionRegistryProvider = Provider<List<WorkbookAction>>((ref) {
  final List<WorkbookAction> builtInActions = [
    WorkbookAction(
      id: 'file.save',
      label: 'Save',
      icon: Icons.save,
      group: WorkbookActionGroup.file,
      isVisible: (state) =>
          !state.readOnly &&
          ref.read(persistenceOptionsProvider)?.onSave != null,
      isEnabled: (state) => state.hasUnsavedChanges,
      onExecute: (context, actionRef) async {
        final options = actionRef.read(persistenceOptionsProvider);
        if (options?.onSave != null) {
          final state = actionRef.read(workbookProvider);
          final success = await options!.onSave!(state.workbook);
          if (success) {
            actionRef.read(workbookProvider.notifier).markAsClean();
          }
        }
      },
    ),
    WorkbookAction(
      id: 'file.saveAs',
      label: 'Save As',
      icon: Icons.save_as,
      group: WorkbookActionGroup.file,
      isVisible: (state) =>
          ref.read(persistenceOptionsProvider)?.onSaveAs != null,
      onExecute: (context, actionRef) async {
        final options = actionRef.read(persistenceOptionsProvider);
        if (options?.onSaveAs != null) {
          final state = actionRef.read(workbookProvider);
          final success = await options!.onSaveAs!(state.workbook);
          if (success) {
            actionRef.read(workbookProvider.notifier).markAsClean();
          }
        }
      },
    ),
    WorkbookAction(
      id: 'file.export.csv',
      label: 'Export to CSV',
      icon: Icons.table_chart_outlined,
      group: WorkbookActionGroup.file,
      onExecute: (context, actionRef) async {
        final state = actionRef.read(workbookProvider);
        final csv = WorkbookExporter.toCsv(state.workbook);
        await Clipboard.setData(ClipboardData(text: csv));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV copied to clipboard')),
          );
        }
      },
    ),
    // Additional built-in actions can be added here
  ];

  return builtInActions;
}, dependencies: [persistenceOptionsProvider]);

final customWorkbookActionsProvider = Provider<List<WorkbookAction>>((ref) {
  return [];
});

final allWorkbookActionsProvider = Provider<List<WorkbookAction>>(
  (ref) {
    final builtIn = ref.watch(workbookActionRegistryProvider);
    final custom = ref.watch(customWorkbookActionsProvider);
    return [...builtIn, ...custom];
  },
  dependencies: [
    workbookActionRegistryProvider,
    customWorkbookActionsProvider,
    persistenceOptionsProvider,
  ],
);
