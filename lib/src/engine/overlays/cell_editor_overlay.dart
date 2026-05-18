import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';
import 'package:sheetifye/src/core/theme/sheetifye_spacing_tokens.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';

class CellEditorOverlay extends ConsumerStatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onCommit;

  const CellEditorOverlay({
    super.key,
    required this.onCancel,
    required this.onCommit,
  });

  @override
  ConsumerState<CellEditorOverlay> createState() => _CellEditorOverlayState();
}

class _CellEditorOverlayState extends ConsumerState<CellEditorOverlay> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final state = ref.read(workbookProvider);
    final initialValue = state.editValue ?? '';

    _controller = TextEditingController(text: initialValue);
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workbookProvider);
    final theme = SheetifyeTheme.of(context);

    if (state.activeCell == null || !state.isEditing) {
      return const SizedBox.shrink();
    }

    ref.listen<WorkbookState>(workbookProvider, (previous, next) {
      if (next.isEditing &&
          next.editValue != null &&
          next.editValue != _controller.text) {
        _controller.text = next.editValue!;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border.all(
          color: state.validationError != null
              ? Colors.redAccent
              : theme.selectionBorderColor,
          width: SheetifyeDimensions.activeCellStrokeWidth,
        ),
        boxShadow: [
          BoxShadow(color: theme.shadowColor, blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final shiftPressed = HardwareKeyboard.instance.isShiftPressed;

            if (event.logicalKey == LogicalKeyboardKey.escape) {
              ref.read(workbookProvider.notifier).cancelEdit();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.tab) {
              final value = _controller.text;
              ref.read(workbookProvider.notifier).commitEdit(value);
              // Only move if commit didn't trigger validation failure
              final nextState = ref.read(workbookProvider);
              if (!nextState.isEditing) {
                ref
                    .read(workbookProvider.notifier)
                    .moveActiveCell(0, shiftPressed ? -1 : 1);
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter) {
              final value = _controller.text;
              ref.read(workbookProvider.notifier).commitEdit(value);
              final nextState = ref.read(workbookProvider);
              if (!nextState.isEditing) {
                ref
                    .read(workbookProvider.notifier)
                    .moveActiveCell(shiftPressed ? -1 : 1, 0);
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.all(SheetifyeSpacingTokens.small),
              ),
              style: theme.gridCellTextStyle,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                ref.read(workbookProvider.notifier).commitEdit(value);
              },
              onChanged: (value) {
                ref.read(workbookProvider.notifier).updateEditValue(value);
              },
            ),
            if (state.validationError != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  border: Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.validationError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(workbookProvider.notifier)
                            .dismissValidationError();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
