import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sheetifye/src/engine/overlays/overlay_manager.dart';
import 'package:sheetifye/src/engine/overlays/position_resolver.dart';
import 'package:sheetifye/src/core/theme/sheetifye_dimensions.dart';

class CutOverlayLayer implements OverlayLayer {
  @override
  OverlayLayerType get type => OverlayLayerType.cut;

  @override
  bool get visible => true;

  @override
  void paint(Canvas canvas, Size size, OverlayContext context) {
    if (context.pendingCutRange == null) return;

    final rect = PositionResolver.getRangeRect(
      context.pendingCutRange!,
      context.sheet,
      context.scrollX,
      context.scrollY,
      context.headerWidth,
      context.headerHeight,
      context.layout,
    );

    // Clip to viewport (avoid drawing over headers)
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        context.headerWidth,
        context.headerHeight,
        size.width - context.headerWidth,
        size.height - context.headerHeight,
      ),
    );

    final borderPaint = Paint()
      ..color = context.theme.primaryColor
      ..strokeWidth = SheetifyeDimensions.gridStrokeWidth * 2
      ..style = PaintingStyle.stroke;

    // Draw dashed border manually
    _drawDashedRect(canvas, rect, borderPaint);

    canvas.restore();
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 3.0;

    // Top
    for (double x = rect.left; x < rect.right; x += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset((x + dashWidth).clamp(rect.left, rect.right), rect.top),
        paint,
      );
    }
    // Bottom
    for (double x = rect.left; x < rect.right; x += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset((x + dashWidth).clamp(rect.left, rect.right), rect.bottom),
        paint,
      );
    }
    // Left
    for (double y = rect.top; y < rect.bottom; y += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.left, (y + dashWidth).clamp(rect.top, rect.bottom)),
        paint,
      );
    }
    // Right
    for (double y = rect.top; y < rect.bottom; y += dashWidth + dashSpace) {
      canvas.drawLine(
        Offset(rect.right, y),
        Offset(rect.right, (y + dashWidth).clamp(rect.top, rect.bottom)),
        paint,
      );
    }
  }
}
