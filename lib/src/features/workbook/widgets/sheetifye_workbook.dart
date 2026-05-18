import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/features/grid/widgets/sheet_grid.dart';
import 'package:sheetifye/src/features/formula_bar/widgets/formula_bar.dart';
import 'package:sheetifye/src/features/tabs/widgets/sheet_tabs.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';
import 'package:sheetifye/src/features/toolbar/widgets/sheetifye_toolbar.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';

import 'package:sheetifye/src/features/toolbar/widgets/mobile_edit_toolbar.dart';
import 'package:sheetifye/src/public/persistence_options.dart';

class SheetifyeWorkbook extends ConsumerStatefulWidget {
  final bool readOnly;

  const SheetifyeWorkbook({super.key, this.readOnly = true});

  @override
  ConsumerState<SheetifyeWorkbook> createState() => _SheetifyeWorkbookState();
}

class _SheetifyeWorkbookState extends ConsumerState<SheetifyeWorkbook> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(workbookProvider.notifier).setReadOnly(widget.readOnly);
    });
  }

  @override
  void didUpdateWidget(SheetifyeWorkbook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readOnly != widget.readOnly) {
      ref.read(workbookProvider.notifier).setReadOnly(widget.readOnly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(workbookProvider.notifier);
    final state = ref.watch(workbookProvider);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
          final isCmdOrCtrl =
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

          if (isCmdOrCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
            if (shiftPressed) {
              _handleSaveAs(ref);
            } else {
              _handleSave(ref);
            }
            return KeyEventResult.handled;
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (shiftPressed) {
              controller.expandSelection(-1, 0);
            } else {
              controller.moveActiveCell(-1, 0);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (shiftPressed) {
              controller.expandSelection(1, 0);
            } else {
              controller.moveActiveCell(1, 0);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (shiftPressed) {
              controller.expandSelection(0, -1);
            } else {
              controller.moveActiveCell(0, -1);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (shiftPressed) {
              controller.expandSelection(0, 1);
            } else {
              controller.moveActiveCell(0, 1);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (!state.readOnly) {
              if (state.isEditing) {
                final value = state.editValue ?? '';
                controller.commitEdit(value);
                controller.moveActiveCell(shiftPressed ? -1 : 1, 0);
              } else {
                controller.setEditing(true);
              }
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.tab) {
            if (!state.readOnly) {
              if (state.isEditing) {
                final value = state.editValue ?? '';
                controller.commitEdit(value);
              }
              controller.moveActiveCell(0, shiftPressed ? -1 : 1);
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (state.isEditing) {
              controller.cancelEdit();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (!state.readOnly &&
                state.mainSelection != null &&
                !state.isEditing) {
              controller.clearRange(state.mainSelection!);
              return KeyEventResult.handled;
            }
          } else {
            // Check for printable direct alphanumeric keys to start editing immediately
            if (!state.readOnly &&
                !state.isEditing &&
                event.character != null &&
                event.character!.isNotEmpty) {
              final char = event.character!;
              final isControl =
                  HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed ||
                  HardwareKeyboard.instance.isAltPressed;
              if (!isControl &&
                  char.length == 1 &&
                  char.codeUnitAt(0) >= 32 &&
                  char.codeUnitAt(0) <= 126) {
                controller.setEditing(true, initialValue: char);
                return KeyEventResult.handled;
              }
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: !state.hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (state.hasUnsavedChanges) {
            final options = ref.read(persistenceOptionsProvider);
            if (options?.onBeforeClose != null) {
              final shouldPop = await options!.onBeforeClose!();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop(result);
              }
            } else {
              final shouldPop = await _showDefaultCloseDialog(
                context,
                options,
                controller,
                state,
              );
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop(result);
              }
            }
          }
        },
        child: Material(
          color: SheetifyeTheme.of(context).backgroundColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SheetifyeToolbar(controller: controller),
                const FormulaBar(),
                const Expanded(child: SheetGrid()),
                const MobileEditToolbar(),
                const SheetTabs(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(WidgetRef ref) async {
    final state = ref.read(workbookProvider);
    final options = ref.read(persistenceOptionsProvider);
    if (options?.onSave != null) {
      final success = await options!.onSave!(state.workbook);
      if (success) {
        ref.read(workbookProvider.notifier).markAsClean();
      }
    }
  }

  Future<void> _handleSaveAs(WidgetRef ref) async {
    final state = ref.read(workbookProvider);
    final options = ref.read(persistenceOptionsProvider);
    if (options?.onSaveAs != null) {
      final success = await options!.onSaveAs!(state.workbook);
      if (success) {
        ref.read(workbookProvider.notifier).markAsClean();
      }
    }
  }

  Future<bool> _showDefaultCloseDialog(
    BuildContext context,
    PersistenceOptions? options,
    WorkbookController controller,
    WorkbookState state,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save your changes before closing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'discard') {
      options?.onDiscardChanges?.call();
      controller.markAsClean();
      return true;
    } else if (result == 'save') {
      if (options?.onSave != null) {
        final success = await options!.onSave!(state.workbook);
        if (success) {
          controller.markAsClean();
          return true;
        }
      } else {
        controller.markAsClean();
        return true;
      }
    }
    return false;
  }
}
