import 'dart:math';
import 'package:flutter/material.dart';


class OrientationIndicator extends StatelessWidget {
  final Color color;

  /// The value is expected to be in radians.

  final double sectorSize;

  const OrientationIndicator({
    Key? key,
    this.color = Colors.blue,
    this.sectorSize = pi/2,
  }) : assert(sectorSize > 0),
       super(key: key);


  @override
  Widget build(context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: OrientationIndicatorPainter(
          color: color,
          sectorSize: sectorSize
        )
      )
    );
  }
}




class OrientationIndicatorPainter extends CustomPainter {
  final Color color;

  /// The value is expected to be in radians.
  /// Setting this to 0 will hide the sector.

  final double sectorSize;

  const OrientationIndicatorPainter({
    this.color = Colors.black,
    this.sectorSize = pi/2
  });


  @override
  void paint(Canvas canvas, Size size) {
    final offset = Offset(size.width/2, size.height/2);

    final radius = min(offset.dx, offset.dy);

    // draw sector

    if (sectorSize > 0) {
      final outerRect = Rect.fromCircle(
        center: offset,
        radius: radius,
      );

      canvas.drawArc(
        outerRect,
        -pi/2 - sectorSize/2,
        sectorSize,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(color.opacity * 1.0),
              color.withOpacity(color.opacity * 0.6),
              color.withOpacity(color.opacity * 0.3),
              color.withOpacity(color.opacity * 0.1),
              color.withOpacity(color.opacity * 0.0),
            ],
          ).createShader(outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(OrientationIndicatorPainter oldDelegate) =>
    oldDelegate.color != color ||
    oldDelegate.sectorSize != sectorSize;
}