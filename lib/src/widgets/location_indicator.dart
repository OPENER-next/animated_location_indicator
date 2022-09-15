import 'package:flutter/material.dart';

class LocationIndicator extends StatelessWidget {
  /// The radius in pixel of the location indicator.

  final double radius;

  final Color color;

  final Color strokeColor;

  final double strokeWidth;

  const LocationIndicator({
    this.radius = 10,
    this.color = Colors.blue,
    this.strokeColor = Colors.white,
    this.strokeWidth = 4,
    Key? key,
  }) : assert(radius > 0),
       super(key: key);

  @override
  Widget build(context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(
          color: strokeColor,
          width: 4
        ),
        boxShadow: kElevationToShadow[4],
        shape: BoxShape.circle,
      ),
      child: SizedBox.fromSize(
        size: Size.fromRadius(radius),
      ),
    );
  }
}
