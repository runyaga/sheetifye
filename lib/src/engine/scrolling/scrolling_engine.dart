import 'package:flutter/material.dart';

class ScrollingEngine {
  final ScrollController horizontalController;
  final ScrollController verticalController;

  ScrollingEngine({
    required this.horizontalController,
    required this.verticalController,
  });

  void scrollToCell(
    int row,
    int col, {
    required double rowHeight,
    required double colWidth,
  }) {
    final x = col * colWidth;
    final y = row * rowHeight;

    if (horizontalController.hasClients) {
      horizontalController.animateTo(
        x,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    if (verticalController.hasClients) {
      verticalController.animateTo(
        y,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void handleAutoScroll(Offset localPosition, Size viewportSize) {
    const threshold = 50.0;
    const speed = 10.0;

    // Horizontal auto-scroll
    if (localPosition.dx < threshold) {
      _scroll(horizontalController, -speed);
    } else if (localPosition.dx > viewportSize.width - threshold) {
      _scroll(horizontalController, speed);
    }

    // Vertical auto-scroll
    if (localPosition.dy < threshold) {
      _scroll(verticalController, -speed);
    } else if (localPosition.dy > viewportSize.height - threshold) {
      _scroll(verticalController, speed);
    }
  }

  void scrollBy(double dx, double dy) {
    _scroll(horizontalController, dx);
    _scroll(verticalController, dy);
  }

  void _scroll(ScrollController controller, double delta) {
    if (controller.hasClients) {
      final current = controller.offset;
      final max = controller.position.maxScrollExtent;
      final min = controller.position.minScrollExtent;

      final target = (current + delta).clamp(min, max);

      if (target != current) {
        controller.jumpTo(target);
      }
    }
  }

  void handleMomentum(Offset velocity, TickerProvider vsync) {
    // This can be expanded to use a simulation, but for now
    // jumpTo is the primary driver. We ensure that manual deltas
    // are never 'stuck' by using the controller's current position.
  }
}
