import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';
import 'package:sheetifye/src/core/theme/sheetifye_spacing_tokens.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';

class MobileEditToolbar extends ConsumerWidget {
  const MobileEditToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workbookProvider);
    final controller = ref.read(workbookProvider.notifier);
    final theme = SheetifyeTheme.of(context);

    // Only display on mobile viewports (< 768px wide) or physical mobile target platforms
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile =
        screenWidth < 768 ||
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    if (!isMobile) {
      return const SizedBox.shrink();
    }

    final Color activeColor = theme.primaryColor;
    final Color inactiveColor = theme.cellTextColor.withValues(alpha: 0.3);

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(
          top: BorderSide(color: theme.gridLineColor),
          bottom: BorderSide(color: theme.gridLineColor),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: SheetifyeSpacingTokens.small,
          ),
          child: Row(
            children: [
              // Undo
              _ToolbarButton(
                icon: Icons.undo_outlined,
                label: 'Undo',
                isEnabled: state.canUndo && !state.readOnly,
                onPressed: () => controller.undo(),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Redo
              _ToolbarButton(
                icon: Icons.redo_outlined,
                label: 'Redo',
                isEnabled: state.canRedo && !state.readOnly,
                onPressed: () => controller.redo(),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Copy
              _ToolbarButton(
                icon: Icons.copy_outlined,
                label: 'Copy',
                isEnabled: state.mainSelection != null,
                onPressed: () => controller.copy(),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Paste
              _ToolbarButton(
                icon: Icons.paste_outlined,
                label: 'Paste',
                isEnabled: !state.readOnly && state.activeCell != null,
                onPressed: () => controller.paste(),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Cut
              _ToolbarButton(
                icon: Icons.content_cut_outlined,
                label: 'Cut',
                isEnabled: !state.readOnly && state.mainSelection != null,
                onPressed: () => controller.cut(),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Select All
              _ToolbarButton(
                icon: Icons.select_all_outlined,
                label: 'Select All',
                isEnabled: true,
                onPressed: () => controller.selectAll(),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Clear Range
              _ToolbarButton(
                icon: Icons.delete_outline,
                label: 'Clear',
                isEnabled: !state.readOnly && state.mainSelection != null,
                onPressed: () {
                  if (state.mainSelection != null) {
                    controller.clearRange(state.mainSelection!);
                  }
                },
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _Divider(color: theme.gridLineColor),
              // Formula / Keyboard
              _ToolbarButton(
                icon: Icons.functions_outlined,
                label: 'Formula',
                isEnabled: !state.readOnly && state.activeCell != null,
                onPressed: () => controller.setEditing(true),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final VoidCallback onPressed;
  final Color activeColor;
  final Color inactiveColor;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.onPressed,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SheetifyeTheme.of(context);
    final Color color = isEnabled ? activeColor : inactiveColor;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(
          SheetifyeDimensions.cornerRadiusSmall,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.tabInactiveTextStyle.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color.withValues(alpha: 0.5),
    );
  }
}
