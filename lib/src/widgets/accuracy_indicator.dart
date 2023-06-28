import 'dart:math';
import 'package:flutter/material.dart';

class AccuracyIndicator extends StatelessWidget {
  final Color color;
  final Color strokeColor;
  final double strokeWidth;

  const AccuracyIndicator({
    this.color = const Color(0x332196F3),
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 0,
    super.key,
  });

  @override
  Widget build(context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CirclePainter(
          color: color,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth
        )
      )
    );
  }
}


class _CirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final Color strokeColor;

  const _CirclePainter({
    this.color = Colors.black,
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 2
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = size.width/2;
    final halfHeight = size.height/2;
    final offset = Offset(halfWidth, halfHeight);
    final radius = min(halfWidth, halfHeight);

    if (color != Colors.transparent) {
      canvas.drawCircle(
        offset,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
      );
    }

    if (strokeColor != Colors.transparent && strokeWidth > 0) {
      canvas.drawCircle(
      offset,
      // make stroke width inset
      radius - strokeWidth/2,
      Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
      );
    }
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) =>
    oldDelegate.color != color ||
    oldDelegate.strokeColor != strokeColor ||
    oldDelegate.strokeWidth != strokeWidth;
}
