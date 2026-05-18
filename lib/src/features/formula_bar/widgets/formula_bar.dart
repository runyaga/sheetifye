import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';
import 'package:sheetifye/src/core/theme/sheetifye_spacing_tokens.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';

class FormulaBar extends ConsumerStatefulWidget {
  const FormulaBar({super.key});

  @override
  ConsumerState<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends ConsumerState<FormulaBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        final state = ref.read(workbookProvider);
        if (!state.readOnly && !state.isEditing) {
          ref.read(workbookProvider.notifier).setEditing(true);
        }
      }
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
    final activeCell = state.activeCell;

    // Determine the current value to display
    String displayValue = '';
    if (state.isEditing) {
      displayValue = state.editValue ?? '';
    } else if (activeCell != null) {
      final cell = state
          .workbook
          .activeSheet
          .cells['${activeCell.row},${activeCell.column}'];
      displayValue = cell?.rawInput ?? cell?.value?.toString() ?? '';
    }

    // Keep controller text in sync when not focused or when value changed externally
    if (!_focusNode.hasFocus && _controller.text != displayValue) {
      _controller.text = displayValue;
    }

    ref.listen<WorkbookState>(workbookProvider, (previous, next) {
      if (next.isEditing &&
          next.editValue != null &&
          next.editValue != _controller.text) {
        _controller.text = next.editValue!;
      } else if (!next.isEditing && previous?.isEditing == true) {
        _controller.clear();
      }
    });

    return Container(
      height: theme.formulaBarHeight,
      padding: SheetifyeSpacingTokens.formulaBarPadding,
      decoration: BoxDecoration(
        color: theme.formulaBarBackgroundColor,
        border: Border(bottom: BorderSide(color: theme.gridLineColor)),
      ),
      child: Row(
        children: [
          // Cell Address Chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SheetifyeSpacingTokens.small,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(
                SheetifyeDimensions.cornerRadiusSmall,
              ),
            ),
            child: Text(
              activeCell?.toA1() ?? '',
              style: theme.formulaBarTextStyle.copyWith(
                color: theme.surfaceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: SheetifyeSpacingTokens.medium),
          // Formula Input Field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !state.readOnly,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: state.readOnly
                    ? ''
                    : 'Enter value or formula (e.g. =A1+B1)',
                hintStyle: theme.formulaBarTextStyle.copyWith(
                  color: theme.formulaBarForegroundColor.withValues(alpha: .5),
                ),
              ),
              style: theme.formulaBarTextStyle.copyWith(
                color: theme.formulaBarForegroundColor,
              ),
              onChanged: (value) {
                ref.read(workbookProvider.notifier).updateEditValue(value);
              },
              onSubmitted: (value) {
                ref.read(workbookProvider.notifier).commitEdit(value);
                _focusNode.unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }
}
