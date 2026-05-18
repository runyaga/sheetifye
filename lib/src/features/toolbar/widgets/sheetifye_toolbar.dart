import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';
import 'package:sheetifye/src/core/theme/sheetifye_spacing_tokens.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';
import 'package:sheetifye/src/features/actions/widgets/workbook_action_menu.dart';

class SheetifyeToolbar extends ConsumerStatefulWidget {
  final WorkbookController controller;

  const SheetifyeToolbar({super.key, required this.controller});

  @override
  ConsumerState<SheetifyeToolbar> createState() => _SheetifyeToolbarState();
}

class _SheetifyeToolbarState extends ConsumerState<SheetifyeToolbar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(workbookProvider).searchQuery ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workbookProvider);
    final theme = SheetifyeTheme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: theme.toolbarHeight + topPadding,
      padding: EdgeInsets.fromLTRB(
        SheetifyeSpacingTokens.small,
        topPadding,
        SheetifyeSpacingTokens.small,
        SheetifyeSpacingTokens.zero,
      ),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (state.isSearchOpen) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: theme.toolbarTextStyle.color,
                size: SheetifyeDimensions.iconSizeMedium,
              ),
              onPressed: () {
                _searchController.clear();
                widget.controller.toggleSearch();
              },
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) => widget.controller.updateSearch(val),
                style: theme.toolbarTextStyle,
                cursorColor: theme.toolbarTextStyle.color,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: theme.toolbarTextStyle.copyWith(
                    color: theme.toolbarTextStyle.color?.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: theme.toolbarTextStyle.color,
                  size: SheetifyeDimensions.iconSizeMedium,
                ),
                onPressed: () {
                  _searchController.clear();
                  widget.controller.updateSearch('');
                },
              ),
          ] else ...[
            Icon(
              Icons.table_chart,
              color: theme.toolbarTextStyle.color?.withValues(alpha: 0.9),
              size: SheetifyeDimensions.iconSizeMedium,
            ),
            const SizedBox(width: SheetifyeSpacingTokens.medium),
            Expanded(
              child: Text(
                '${state.workbook.name}${state.hasUnsavedChanges ? '*' : ''}',
                style: theme.toolbarTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _ToolbarIcon(
              icon: Icons.search,
              onPressed: () => widget.controller.toggleSearch(),
            ),
            const WorkbookActionMenuButton(),
          ],
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _ToolbarIcon({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = SheetifyeTheme.of(context);
    return IconButton(
      icon: Icon(
        icon,
        size: SheetifyeDimensions.iconSizeLarge,
        color: theme.toolbarTextStyle.color,
      ),
      onPressed: onPressed,
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(SheetifyeSpacingTokens.small),
    );
  }
}
