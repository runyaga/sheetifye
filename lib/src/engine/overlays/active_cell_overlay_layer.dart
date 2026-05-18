import 'package:flutter/material.dart';
import 'package:sheetifye/sheetifye.dart';
import 'package:sheetifye/src/engine/overlays/overlay_manager.dart';
import 'package:sheetifye/src/engine/overlays/position_resolver.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';

class ActiveCellOverlayLayer implements OverlayLayer {
  @override
  OverlayLayerType get type => OverlayLayerType.activeCell;

  @override
  bool get visible => true;

  @override
  void paint(Canvas canvas, Size size, OverlayContext context) {
    if (context.activeCell == null) return;

    final paint = Paint()
      ..color = context.theme.selectionBorderColor
      ..strokeWidth = SheetifyeDimensions.activeCellStrokeWidth
      ..style = PaintingStyle.stroke;

    final rect = PositionResolver.getCellRect(
      context.activeCell!.row,
      context.activeCell!.column,
      context.sheet,
      context.scrollX,
      context.scrollY,
      context.headerWidth,
      context.headerHeight,
      context.layout,
    );

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        context.headerWidth,
        context.headerHeight,
        size.width - context.headerWidth,
        size.height - context.headerHeight,
      ),
    );

    // Draw active cell outline
    canvas.drawRect(rect, paint);

    // Draw selection handle (autofill handle) at the bottom-right corner of the entire selection
    final selection =
        context.mainSelection ??
        GridRange.fromRect(
          context.activeCell!.row,
          context.activeCell!.column,
          context.activeCell!.row,
          context.activeCell!.column,
        );

    final selectionRect = PositionResolver.getRangeRect(
      selection,
      context.sheet,
      context.scrollX,
      context.scrollY,
      context.headerWidth,
      context.headerHeight,
      context.layout,
    );

    const handleSize = SheetifyeDimensions.selectionHandleSize;
    final handleRect = Rect.fromCenter(
      center: selectionRect.bottomRight,
      width: handleSize,
      height: handleSize,
    );
    final handlePaint = Paint()
      ..color = context.theme.selectionBorderColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(handleRect, handlePaint);

    canvas.restore();
  }
}
