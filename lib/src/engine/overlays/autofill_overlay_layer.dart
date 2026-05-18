import 'package:flutter/material.dart';
import 'package:sheetifye/src/engine/overlays/overlay_manager.dart';
import 'package:sheetifye/src/engine/overlays/position_resolver.dart';

class AutofillOverlayLayer implements OverlayLayer {
  @override
  OverlayLayerType get type => OverlayLayerType.autofill;

  @override
  bool get visible => true;

  @override
  void paint(Canvas canvas, Size size, OverlayContext context) {
    if (context.autofillRange == null) return;

    final rect = PositionResolver.getRangeRect(
      context.autofillRange!,
      context.sheet,
      context.scrollX,
      context.scrollY,
      context.headerWidth,
      context.headerHeight,
      context.layout,
    );

    final paint = Paint()
      ..color = context.theme.selectionBorderColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        context.headerWidth,
        context.headerHeight,
        size.width - context.headerWidth,
        size.height - context.headerHeight,
      ),
    );

    // Draw dashed rectangle around projected fill area
    _drawDashedRect(canvas, rect, paint, dashWidth: 5, dashSpace: 3);

    canvas.restore();
  }

  void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    double dashWidth = 5,
    double dashSpace = 3,
  }) {
    final double step = dashWidth + dashSpace;

    // Top border
    for (double x = rect.left; x < rect.right; x += step) {
      final double endX = (x + dashWidth).clamp(rect.left, rect.right);
      canvas.drawLine(Offset(x, rect.top), Offset(endX, rect.top), paint);
    }

    // Bottom border
    for (double x = rect.left; x < rect.right; x += step) {
      final double endX = (x + dashWidth).clamp(rect.left, rect.right);
      canvas.drawLine(Offset(x, rect.bottom), Offset(endX, rect.bottom), paint);
    }

    // Left border
    for (double y = rect.top; y < rect.bottom; y += step) {
      final double endY = (y + dashWidth).clamp(rect.top, rect.bottom);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.left, endY), paint);
    }

    // Right border
    for (double y = rect.top; y < rect.bottom; y += step) {
      final double endY = (y + dashWidth).clamp(rect.top, rect.bottom);
      canvas.drawLine(Offset(rect.right, y), Offset(rect.right, endY), paint);
    }
  }
}
