import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';
import 'package:sheetifye/src/features/actions/models/workbook_action.dart';
import 'package:sheetifye/src/features/actions/registry/workbook_action_registry.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';
import 'package:sheetifye/src/core/theme/sheetifye_spacing_tokens.dart';

class WorkbookActionMenuButton extends ConsumerWidget {
  const WorkbookActionMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = SheetifyeTheme.of(context);
    final state = ref.watch(workbookProvider);
    final actions = ref.watch(allWorkbookActionsProvider);

    // Filter visible actions
    final visibleActions = actions.where((action) {
      if (action.isVisible != null) {
        return action.isVisible!(state);
      }
      return true;
    }).toList();

    if (visibleActions.isEmpty) return const SizedBox.shrink();

    // Group actions
    final Map<WorkbookActionGroup, List<WorkbookAction>> groupedActions = {};
    for (final action in visibleActions) {
      groupedActions.putIfAbsent(action.group, () => []).add(action);
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return IconButton(
        icon: Icon(
          Icons.more_vert,
          size: SheetifyeDimensions.iconSizeMedium,
          color: theme.toolbarTextStyle.color,
        ),
        onPressed: () => _showBottomSheet(context, ref, groupedActions, state),
      );
    } else {
      return _buildDesktopMenu(context, ref, theme, groupedActions, state);
    }
  }

  // ─── Desktop: PopupMenuButton ───────────────────────────────────────

  Widget _buildDesktopMenu(
    BuildContext context,
    WidgetRef ref,
    dynamic theme,
    Map<WorkbookActionGroup, List<WorkbookAction>> groupedActions,
    WorkbookState state,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: theme.surfaceColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              SheetifyeDimensions.cornerRadiusMedium,
            ),
            side: BorderSide(color: theme.gridLineColor, width: 0.5),
          ),
          elevation: 8,
          shadowColor: theme.shadowColor,
        ),
      ),
      child: PopupMenuButton<WorkbookAction>(
        icon: Icon(
          Icons.more_vert,
          size: SheetifyeDimensions.iconSizeMedium,
          color: theme.toolbarTextStyle.color,
        ),
        offset: const Offset(0, SheetifyeDimensions.toolbarHeight),
        onSelected: (action) async {
          if (action.isEnabled == null || action.isEnabled!(state)) {
            await action.onExecute(context, ref);
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<WorkbookAction>>[];
          int groupIndex = 0;
          for (final entry in groupedActions.entries) {
            if (groupIndex > 0) {
              items.add(const PopupMenuDivider(height: 1));
            }
            for (final action in entry.value) {
              final isEnabled =
                  action.isEnabled == null || action.isEnabled!(state);
              items.add(
                PopupMenuItem<WorkbookAction>(
                  value: action,
                  enabled: isEnabled,
                  height: 44,
                  child: Row(
                    children: [
                      Icon(
                        action.icon,
                        size: SheetifyeDimensions.iconSizeMedium,
                        color: isEnabled
                            ? theme.cellTextColor
                            : theme.gridLineColor,
                      ),
                      const SizedBox(width: SheetifyeSpacingTokens.medium),
                      Text(
                        action.label,
                        style: theme.gridCellTextStyle.copyWith(
                          color: isEnabled
                              ? theme.cellTextColor
                              : theme.gridLineColor,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            groupIndex++;
          }
          return items;
        },
      ),
    );
  }

  // ─── Mobile: Drag-handle bottom sheet ───────────────────────────────

  void _showBottomSheet(
    BuildContext context,
    WidgetRef ref,
    Map<WorkbookActionGroup, List<WorkbookAction>> groupedActions,
    WorkbookState state,
  ) {
    final theme = SheetifyeTheme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.gridLineColor,
                    borderRadius: BorderRadius.circular(
                      SheetifyeDimensions.cornerRadiusCircular,
                    ),
                  ),
                ),
              ),

              // ── Title Row ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SheetifyeSpacingTokens.large,
                  vertical: SheetifyeSpacingTokens.small,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.table_chart_rounded,
                      size: SheetifyeDimensions.iconSizeMedium,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: SheetifyeSpacingTokens.small),
                    Text(
                      'Workbook Actions',
                      style: theme.gridCellTextStyle.copyWith(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: theme.cellTextColor,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.close_rounded,
                          size: SheetifyeDimensions.iconSizeMedium,
                          color: theme.headerForegroundColor,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: theme.gridLineColor, height: 1),

              // ── Action Groups ──
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(
                    bottom: SheetifyeSpacingTokens.large,
                  ),
                  children: [
                    for (int i = 0; i < groupedActions.length; i++) ...[
                      if (i > 0)
                        Divider(
                          color: theme.gridLineColor,
                          height: 1,
                          indent: SheetifyeSpacingTokens.large,
                          endIndent: SheetifyeSpacingTokens.large,
                        ),
                      _buildGroupSection(
                        ctx,
                        ref,
                        theme,
                        groupedActions.keys.elementAt(i),
                        groupedActions.values.elementAt(i),
                        state,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupSection(
    BuildContext sheetCtx,
    WidgetRef ref,
    dynamic theme,
    WorkbookActionGroup group,
    List<WorkbookAction> actions,
    WorkbookState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Group Header ──
        Padding(
          padding: const EdgeInsets.only(
            left: SheetifyeSpacingTokens.large,
            right: SheetifyeSpacingTokens.large,
            top: SheetifyeSpacingTokens.medium,
            bottom: SheetifyeSpacingTokens.xSmall,
          ),
          child: Text(
            group.label.toUpperCase(),
            style: theme.gridHeaderTextStyle.copyWith(
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: theme.headerForegroundColor,
            ),
          ),
        ),

        // ── Action Tiles ──
        ...actions.map((action) {
          final isEnabled =
              action.isEnabled == null || action.isEnabled!(state);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled
                  ? () async {
                      Navigator.of(sheetCtx).pop();
                      await action.onExecute(sheetCtx, ref);
                    }
                  : null,
              splashColor: theme.selectionColor,
              highlightColor: theme.selectionColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SheetifyeSpacingTokens.large,
                  vertical: SheetifyeSpacingTokens.medium,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? theme.primaryColor.withValues(alpha: 0.1)
                            : theme.gridLineColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          SheetifyeDimensions.cornerRadiusMedium,
                        ),
                      ),
                      child: Icon(
                        action.icon,
                        size: SheetifyeDimensions.iconSizeMedium,
                        color: isEnabled
                            ? theme.primaryColor
                            : theme.gridLineColor,
                      ),
                    ),
                    const SizedBox(width: SheetifyeSpacingTokens.medium),
                    Expanded(
                      child: Text(
                        action.label,
                        style: theme.gridCellTextStyle.copyWith(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          color: isEnabled
                              ? theme.cellTextColor
                              : theme.gridLineColor,
                        ),
                      ),
                    ),
                    if (!isEnabled)
                      Icon(
                        Icons.lock_outline_rounded,
                        size: SheetifyeDimensions.iconSizeSmall,
                        color: theme.gridLineColor,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
