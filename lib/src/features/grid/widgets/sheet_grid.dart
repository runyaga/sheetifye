import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme.dart';
import 'package:sheetifye/src/core/theme/sheetifye_theme_data.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';
import 'package:sheetifye/src/features/workbook/state/workbook_state.dart';
import 'package:sheetifye/src/engine/render/grid_painter.dart';
import 'package:sheetifye/src/engine/scrolling/scrolling_engine.dart';
import 'package:sheetifye/src/engine/render/text_painter_cache.dart';
import 'package:sheetifye/src/core/utils/grid_utils.dart';
import 'package:sheetifye/src/domain/entities/workbook.dart';
import 'package:sheetifye/src/engine/overlays/overlay_manager.dart';
import 'package:sheetifye/src/engine/overlays/selection_overlay_layer.dart';
import 'package:sheetifye/src/engine/overlays/active_cell_overlay_layer.dart';
import 'package:sheetifye/src/engine/overlays/search_overlay_layer.dart';
import 'package:sheetifye/src/engine/overlays/position_resolver.dart';
import 'package:sheetifye/src/engine/overlays/cell_editor_overlay.dart';
import 'package:sheetifye/src/engine/layout/layout_engine.dart';
import 'package:sheetifye/src/engine/layout/layout_interaction.dart';
import 'package:sheetifye/src/engine/virtualization/virtualization_engine.dart';

import 'package:sheetifye/src/engine/overlays/autofill_overlay_layer.dart';
import 'package:sheetifye/src/engine/overlays/cut_overlay_layer.dart';

class SheetGrid extends ConsumerStatefulWidget {
  const SheetGrid({super.key});

  @override
  ConsumerState<SheetGrid> createState() => _SheetGridState();
}

class _SheetGridState extends ConsumerState<SheetGrid> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;
  late ScrollingEngine _scrollingEngine;
  final _textPainterCache = TextPainterCache();
  final _overlayManager = OverlayManager();

  LayoutInteractionState _interactionState = LayoutInteractionState();

  double _scrollX = 0;
  double _scrollY = 0;
  final bool _isSyncing = false;

  // Gesture state variables
  bool _isSelectionDragging = false;
  bool _isAutofillDragging = false;
  GridRange? _autofillSourceRange;
  GridRange? _autofillTargetRange;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController()..addListener(_onScroll);
    _verticalController = ScrollController()..addListener(_onScroll);

    _scrollingEngine = ScrollingEngine(
      horizontalController: _horizontalController,
      verticalController: _verticalController,
    );

    _overlayManager.addLayer(SelectionOverlayLayer());
    _overlayManager.addLayer(ActiveCellOverlayLayer());
    _overlayManager.addLayer(SearchOverlayLayer());
    _overlayManager.addLayer(AutofillOverlayLayer());
    _overlayManager.addLayer(CutOverlayLayer());
  }

  void _onScroll() {
    if (_isSyncing) return;

    setState(() {
      _scrollX = _horizontalController.hasClients
          ? _horizontalController.offset
          : 0;
      _scrollY = _verticalController.hasClients
          ? _verticalController.offset
          : 0;
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _textPainterCache.clear();
    super.dispose();
  }

  bool _isHitAutofillHandle(
    Offset localPosition,
    LayoutEngine layout,
    SheetifyeThemeData theme,
  ) {
    final state = ref.read(workbookProvider);
    if (state.activeCell == null) return false;

    final selection =
        state.mainSelection ??
        GridRange.fromRect(
          state.activeCell!.row,
          state.activeCell!.column,
          state.activeCell!.row,
          state.activeCell!.column,
        );

    final rect = PositionResolver.getRangeRect(
      selection,
      state.workbook.activeSheet,
      _scrollX,
      _scrollY,
      theme.rowHeaderWidth,
      theme.columnHeaderHeight,
      layout,
    );

    final handleCenter = rect.bottomRight;
    const hitPadding = 12.0; // larger hit box for easier pointer/touch hits
    final hitRect = Rect.fromCenter(
      center: handleCenter,
      width: hitPadding * 2,
      height: hitPadding * 2,
    );

    return hitRect.contains(localPosition);
  }

  void _handlePointerDown(
    PointerDownEvent event,
    LayoutEngine layout,
    SheetifyeThemeData theme,
  ) {
    if (event.buttons != kPrimaryButton) return;

    // Only allow mouse dragging for cell actions (touch scrolls by default)
    if (event.kind != PointerDeviceKind.mouse) return;

    final localPosition = event.localPosition;

    if (_isHitAutofillHandle(localPosition, layout, theme)) {
      final state = ref.read(workbookProvider);
      final selection =
          state.mainSelection ??
          GridRange.fromRect(
            state.activeCell!.row,
            state.activeCell!.column,
            state.activeCell!.row,
            state.activeCell!.column,
          );
      setState(() {
        _isAutofillDragging = true;
        _autofillSourceRange = selection;
        _autofillTargetRange = null;
      });
    } else {
      final double gridX = localPosition.dx - theme.rowHeaderWidth;
      final double gridY = localPosition.dy - theme.columnHeaderHeight;
      if (gridX >= 0 && gridY >= 0) {
        final double adjustedX = gridX + _scrollX;
        final double adjustedY = gridY + _scrollY;
        final state = ref.read(workbookProvider);
        final col = layout.getColumnIndex(
          adjustedX,
          state.workbook.activeSheet.columnCount,
        );
        final row = layout.getRowIndex(
          adjustedY,
          state.workbook.activeSheet.rowCount,
        );

        setState(() {
          _isSelectionDragging = true;
        });
        ref.read(workbookProvider.notifier).startDrag(row, col);
      }
    }
  }

  void _handlePointerMove(
    PointerMoveEvent event,
    LayoutEngine layout,
    Sheet sheet,
    SheetifyeThemeData theme,
  ) {
    if (_isAutofillDragging && _autofillSourceRange != null) {
      final double gridX = event.localPosition.dx - theme.rowHeaderWidth;
      final double gridY = event.localPosition.dy - theme.columnHeaderHeight;
      final double adjustedX = gridX + _scrollX;
      final double adjustedY = gridY + _scrollY;
      final col = layout.getColumnIndex(adjustedX, sheet.columnCount);
      final row = layout.getRowIndex(adjustedY, sheet.rowCount);

      // Choose whether drag is primary horizontal or vertical
      final int rowDiff = row > _autofillSourceRange!.maxRow
          ? (row - _autofillSourceRange!.maxRow)
          : (row < _autofillSourceRange!.minRow
                ? (_autofillSourceRange!.minRow - row)
                : 0);
      final int colDiff = col > _autofillSourceRange!.maxCol
          ? (col - _autofillSourceRange!.maxCol)
          : (col < _autofillSourceRange!.minCol
                ? (_autofillSourceRange!.minCol - col)
                : 0);

      GridRange? targetRange;
      if (rowDiff >= colDiff && rowDiff > 0) {
        if (row > _autofillSourceRange!.maxRow) {
          targetRange = GridRange.fromRect(
            _autofillSourceRange!.maxRow + 1,
            _autofillSourceRange!.minCol,
            row,
            _autofillSourceRange!.maxCol,
          );
        } else if (row < _autofillSourceRange!.minRow) {
          targetRange = GridRange.fromRect(
            row,
            _autofillSourceRange!.minCol,
            _autofillSourceRange!.minRow - 1,
            _autofillSourceRange!.maxCol,
          );
        }
      } else if (colDiff > rowDiff && colDiff > 0) {
        if (col > _autofillSourceRange!.maxCol) {
          targetRange = GridRange.fromRect(
            _autofillSourceRange!.minRow,
            _autofillSourceRange!.maxCol + 1,
            _autofillSourceRange!.maxRow,
            col,
          );
        } else if (col < _autofillSourceRange!.minCol) {
          targetRange = GridRange.fromRect(
            _autofillSourceRange!.minRow,
            col,
            _autofillSourceRange!.maxRow,
            _autofillSourceRange!.minCol - 1,
          );
        }
      }

      setState(() {
        _autofillTargetRange = targetRange;
      });
    } else if (_isSelectionDragging) {
      final double gridX = event.localPosition.dx - theme.rowHeaderWidth;
      final double gridY = event.localPosition.dy - theme.columnHeaderHeight;
      final double adjustedX = gridX + _scrollX;
      final double adjustedY = gridY + _scrollY;
      final col = layout.getColumnIndex(adjustedX, sheet.columnCount);
      final row = layout.getRowIndex(adjustedY, sheet.rowCount);

      ref.read(workbookProvider.notifier).updateDrag(row, col);
    } else {
      // Normal panning/scrolling (runs for mobile touches or trackpad drags)
      if (event.buttons == kPrimaryButton ||
          event.kind == PointerDeviceKind.touch) {
        _scrollingEngine.scrollBy(-event.delta.dx, -event.delta.dy);
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isAutofillDragging) {
      if (_autofillSourceRange != null && _autofillTargetRange != null) {
        ref
            .read(workbookProvider.notifier)
            .autofill(_autofillSourceRange!, _autofillTargetRange!);
      }
      setState(() {
        _isAutofillDragging = false;
        _autofillSourceRange = null;
        _autofillTargetRange = null;
      });
    } else if (_isSelectionDragging) {
      ref.read(workbookProvider.notifier).endDrag();
      setState(() {
        _isSelectionDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workbookProvider);
    final layout = ref.watch(layoutProvider);
    final sheet = state.workbook.activeSheet;
    final theme = SheetifyeTheme.of(context);

    final virtualizationEngine = VirtualizationEngine(layout: layout);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth - theme.rowHeaderWidth;
        final totalHeight = constraints.maxHeight - theme.columnHeaderHeight;

        final currentX = _scrollX;
        final currentY = _scrollY;

        final viewportRange = virtualizationEngine.calculateViewportRange(
          scrollX: currentX,
          scrollY: currentY,
          viewportWidth: totalWidth,
          viewportHeight: totalHeight,
          totalRows: sheet.rowCount,
          totalCols: sheet.columnCount,
        );

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
                ref.read(workbookProvider.notifier).undo(),
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
                ref.read(workbookProvider.notifier).undo(),
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
                ref.read(workbookProvider.notifier).redo(),
            const SingleActivator(LogicalKeyboardKey.keyY, meta: true): () =>
                ref.read(workbookProvider.notifier).redo(),
            const SingleActivator(LogicalKeyboardKey.keyC, control: true): () =>
                ref.read(workbookProvider.notifier).copy(),
            const SingleActivator(LogicalKeyboardKey.keyC, meta: true): () =>
                ref.read(workbookProvider.notifier).copy(),
            if (!state.readOnly) ...{
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): () =>
                  ref.read(workbookProvider.notifier).paste(),
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
                  ref.read(workbookProvider.notifier).paste(),
              const SingleActivator(
                LogicalKeyboardKey.keyX,
                control: true,
              ): () =>
                  ref.read(workbookProvider.notifier).cut(),
              const SingleActivator(LogicalKeyboardKey.keyX, meta: true): () =>
                  ref.read(workbookProvider.notifier).cut(),
            },
          },
          child: MouseRegion(
            cursor: _getCursor(),
            onHover: (event) => _handleGlobalHover(event, layout, sheet, theme),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final metrics = notification.metrics;
                  if (metrics.axis == Axis.vertical) {
                    if (metrics.pixels > metrics.maxScrollExtent - 500) {
                      final currentRow = layout.getRowIndex(
                        metrics.pixels,
                        sheet.rowCount,
                      );
                      ref
                          .read(workbookProvider.notifier)
                          .expandIfNeeded(currentRow + 50, 0);
                    }
                  } else {
                    if (metrics.pixels > metrics.maxScrollExtent - 500) {
                      final currentCol = layout.getColumnIndex(
                        metrics.pixels,
                        sheet.columnCount,
                      );
                      ref
                          .read(workbookProvider.notifier)
                          .expandIfNeeded(0, currentCol + 10);
                    }
                  }
                }
                return false;
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    _scrollingEngine.scrollBy(
                      pointerSignal.scrollDelta.dx,
                      pointerSignal.scrollDelta.dy,
                    );
                  }
                },
                onPointerDown: (event) =>
                    _handlePointerDown(event, layout, theme),
                onPointerMove: (event) =>
                    _handlePointerMove(event, layout, sheet, theme),
                onPointerUp: _handlePointerUp,
                child: GestureDetector(
                  onTapDown: (details) =>
                      _handleGesture(details.localPosition, layout, theme),
                  onDoubleTapDown: (details) => _handleGesture(
                    details.localPosition,
                    layout,
                    theme,
                    isDoubleTap: true,
                  ),
                  child: Stack(
                    children: [
                      // Layer 1: Base Grid
                      Positioned(
                        left: theme.rowHeaderWidth,
                        top: theme.columnHeaderHeight,
                        right: 0,
                        bottom: 0,
                        child: ClipRect(
                          child: _buildGridPart(
                            sheet: sheet,
                            range: viewportRange,
                            theme: theme,
                            sx: currentX,
                            sy: currentY,
                            w: totalWidth,
                            h: totalHeight,
                            layout: layout,
                          ),
                        ),
                      ),

                      // Layer 2: Overlays
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _OverlayPainter(
                              context: OverlayContext(
                                sheet: sheet,
                                theme: theme,
                                activeCell: state.activeCell,
                                mainSelection: state.mainSelection,
                                additionalSelections:
                                    state.additionalSelections,
                                autofillRange: _autofillTargetRange,
                                scrollX: currentX,
                                scrollY: currentY,
                                headerWidth: theme.rowHeaderWidth,
                                headerHeight: theme.columnHeaderHeight,
                                layout: layout,
                                searchQuery: state.searchQuery,
                                pendingCutRange:
                                    state.pendingCutSheetId == sheet.id
                                    ? state.pendingCutRange
                                    : null,
                              ),
                              manager: _overlayManager,
                            ),
                          ),
                        ),
                      ),

                      // Layer 3: Headers
                      _buildHeaders(
                        sheet,
                        theme,
                        layout,
                        currentX,
                        currentY,
                        viewportRange,
                      ),

                      // Layer 4: Editor
                      if (state.isEditing && state.activeCell != null)
                        _buildEditorOverlay(
                          state,
                          sheet,
                          layout,
                          theme,
                          currentX,
                          currentY,
                        ),

                      // Layer 5: Scrollbars
                      _buildScrollbars(sheet, layout, theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MouseCursor _getCursor() {
    if (_interactionState.hoveredZone != null) {
      return _interactionState.hoveredZone!.direction ==
              ResizeDirection.horizontal
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown;
    }
    return MouseCursor.defer;
  }

  void _handleGlobalHover(
    PointerHoverEvent event,
    LayoutEngine layout,
    Sheet sheet,
    SheetifyeThemeData theme,
  ) {
    final x = event.localPosition.dx;
    final y = event.localPosition.dy;

    if (y < theme.columnHeaderHeight && x > theme.rowHeaderWidth) {
      _detectColumnResizeZone(x - theme.rowHeaderWidth, layout, sheet, theme);
    } else {
      if (_interactionState.hoveredZone != null) {
        setState(
          () =>
              _interactionState = _interactionState.copyWith(clearHover: true),
        );
      }
    }
  }

  void _detectColumnResizeZone(
    double x,
    LayoutEngine layout,
    Sheet sheet,
    SheetifyeThemeData theme,
  ) {
    const threshold = 4.0;
    final scrollX = _scrollX;

    final colIndex = layout.getColumnIndex(x + scrollX, sheet.columnCount);
    final colOffset =
        layout.getColumnOffset(colIndex + 1, sheet.columnCount) - scrollX;

    if ((x - colOffset).abs() < threshold) {
      setState(() {
        _interactionState = _interactionState.copyWith(
          hoveredZone: ResizeZone(
            index: colIndex,
            direction: ResizeDirection.horizontal,
            hitRect: Rect.fromLTWH(
              colOffset - threshold,
              0,
              threshold * 2,
              theme.columnHeaderHeight,
            ),
          ),
        );
      });
    } else if (_interactionState.hoveredZone != null) {
      setState(
        () => _interactionState = _interactionState.copyWith(clearHover: true),
      );
    }
  }

  Widget _buildGridPart({
    required Sheet sheet,
    required ViewportRange range,
    required SheetifyeThemeData theme,
    required double sx,
    required double sy,
    required double w,
    required double h,
    required LayoutEngine layout,
  }) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GridPainter(
          sheet: sheet,
          viewportRange: range,
          theme: theme,
          scrollX: sx,
          scrollY: sy,
          textPainterCache: _textPainterCache,
          layout: layout,
        ),
      ),
    );
  }

  void _handleGesture(
    Offset localPosition,
    LayoutEngine layout,
    SheetifyeThemeData theme, {
    bool isDoubleTap = false,
  }) {
    final state = ref.read(workbookProvider);
    final sheet = state.workbook.activeSheet;

    final double gridX = localPosition.dx - theme.rowHeaderWidth;
    final double gridY = localPosition.dy - theme.columnHeaderHeight;

    final notifier = ref.read(workbookProvider.notifier);

    if (gridX >= 0 && gridY >= 0) {
      final double adjustedX = gridX + _scrollX;
      final double adjustedY = gridY + _scrollY;

      final col = layout.getColumnIndex(adjustedX, sheet.columnCount);
      final row = layout.getRowIndex(adjustedY, sheet.rowCount);

      if (state.isEditing) {
        final value = state.editValue ?? '';
        notifier.commitEdit(value);
        if (state.activeCell?.row == row && state.activeCell?.column == col) {
          return;
        }
      }

      if (isDoubleTap) {
        notifier.selectCell(row, col);
        notifier.setEditing(true);
      } else {
        notifier.selectCell(row, col);
      }
    }
  }

  Widget _buildHeaders(
    Sheet sheet,
    SheetifyeThemeData theme,
    LayoutEngine layout,
    double scrollX,
    double scrollY,
    ViewportRange range,
  ) {
    return Stack(
      children: [
        // Column Headers
        Positioned(
          left: theme.rowHeaderWidth,
          top: 0,
          right: 0,
          height: theme.columnHeaderHeight,
          child: ClipRect(
            child: CustomPaint(
              painter: _HeaderPainter(
                sheet: sheet,
                theme: theme,
                layout: layout,
                scroll: scrollX,
                axis: Axis.horizontal,
                range: range,
              ),
            ),
          ),
        ),

        // Row Headers
        Positioned(
          left: 0,
          top: theme.columnHeaderHeight,
          bottom: 0,
          width: theme.rowHeaderWidth,
          child: ClipRect(
            child: CustomPaint(
              painter: _HeaderPainter(
                sheet: sheet,
                theme: theme,
                layout: layout,
                scroll: scrollY,
                axis: Axis.vertical,
                range: range,
              ),
            ),
          ),
        ),

        // Top-Left Corner
        Positioned(
          left: 0,
          top: 0,
          width: theme.rowHeaderWidth,
          height: theme.columnHeaderHeight,
          child: Container(
            decoration: BoxDecoration(
              color: theme.headerBackgroundColor,
              border: Border.all(
                color: theme.gridLineColor,
                width: SheetifyeDimensions.gridStrokeWidth,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorOverlay(
    WorkbookState state,
    Sheet sheet,
    LayoutEngine layout,
    SheetifyeThemeData theme,
    double scrollX,
    double scrollY,
  ) {
    final rect = PositionResolver.getCellRect(
      state.activeCell!.row,
      state.activeCell!.column,
      sheet,
      scrollX,
      scrollY,
      theme.rowHeaderWidth,
      theme.columnHeaderHeight,
      layout,
    );

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      child: CellEditorOverlay(
        onCancel: () => ref.read(workbookProvider.notifier).cancelEdit(),
        onCommit: (val) => ref.read(workbookProvider.notifier).commitEdit(val),
      ),
    );
  }

  Widget _buildScrollbars(
    Sheet sheet,
    LayoutEngine layout,
    SheetifyeThemeData theme,
  ) {
    return Stack(
      children: [
        Positioned(
          right: 0,
          top: theme.columnHeaderHeight,
          bottom: 0,
          child: SizedBox(
            width: 12,
            child: RawScrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              thickness: 8,
              radius: const Radius.circular(
                SheetifyeDimensions.cornerRadiusSmall,
              ),
              child: SingleChildScrollView(
                controller: _verticalController,
                child: SizedBox(height: layout.getTotalHeight(sheet.rowCount)),
              ),
            ),
          ),
        ),
        Positioned(
          left: theme.rowHeaderWidth,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 12,
            child: RawScrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              thickness: 8,
              radius: const Radius.circular(
                SheetifyeDimensions.cornerRadiusSmall,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalController,
                child: SizedBox(width: layout.getTotalWidth(sheet.columnCount)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderPainter extends CustomPainter {
  final Sheet sheet;
  final SheetifyeThemeData theme;
  final LayoutEngine layout;
  final double scroll;
  final Axis axis;
  final ViewportRange range;

  _HeaderPainter({
    required this.sheet,
    required this.theme,
    required this.layout,
    required this.scroll,
    required this.axis,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = theme.gridLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = SheetifyeDimensions.gridStrokeWidth;

    final bgPaint = Paint()..color = theme.headerBackgroundColor;

    if (axis == Axis.horizontal) {
      for (int c = range.startColumn; c <= range.endColumn; c++) {
        final x = layout.getColumnOffset(c, sheet.columnCount) - scroll;
        final w = layout.getColumnWidth(c, sheet);
        final rect = Rect.fromLTWH(x, 0, w, size.height);

        canvas.drawRect(rect, bgPaint);
        canvas.drawRect(rect, paint);

        final text = GridUtils.getColumnLabel(c);
        _drawText(canvas, text, rect);
      }
    } else {
      for (int r = range.startRow; r <= range.endRow; r++) {
        final y = layout.getRowOffset(r, sheet) - scroll;
        final h = layout.getRowHeight(r, sheet);
        final rect = Rect.fromLTWH(0, y, size.width, h);

        canvas.drawRect(rect, bgPaint);
        canvas.drawRect(rect, paint);

        final text = '${r + 1}';
        _drawText(canvas, text, rect);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Rect rect) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: theme.gridHeaderTextStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter oldDelegate) {
    return oldDelegate.scroll != scroll ||
        oldDelegate.range != range ||
        oldDelegate.sheet != sheet ||
        oldDelegate.theme != theme;
  }
}

class _OverlayPainter extends CustomPainter {
  final OverlayContext context;
  final OverlayManager manager;

  _OverlayPainter({required this.context, required this.manager});

  @override
  void paint(Canvas canvas, Size size) {
    manager.paint(canvas, size, context);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.context != context;
  }
}
