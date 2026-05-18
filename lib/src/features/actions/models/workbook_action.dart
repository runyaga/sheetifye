import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';

/// Categories for organizing workbook actions in menus.
enum WorkbookActionGroup {
  file('File'),
  sharing('Share'),
  workbook('Workbook'),
  view('View'),
  developer('Developer'),
  other('Other');

  final String label;
  const WorkbookActionGroup(this.label);
}

/// Represents an executable action in the workbook.
class WorkbookAction {
  /// Unique identifier for the action.
  final String id;

  /// Human-readable label displayed in UI.
  final String label;

  /// Icon to represent the action.
  final IconData icon;

  /// The group this action belongs to (for visual separation).
  final WorkbookActionGroup group;

  /// Determines if the action is currently visible in the UI.
  final bool Function(WorkbookState state)? isVisible;

  /// Determines if the action is currently enabled.
  final bool Function(WorkbookState state)? isEnabled;

  /// The asynchronous callback executed when the action is triggered.
  final Future<void> Function(BuildContext context, WidgetRef ref) onExecute;

  const WorkbookAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.isVisible,
    this.isEnabled,
    required this.onExecute,
  });
}
