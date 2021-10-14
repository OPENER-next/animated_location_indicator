import 'package:flutter/material.dart';

class LocationIndicator extends StatelessWidget {
  final Color color;

  final Color strokeColor;

  final double strokeWidth;

  const LocationIndicator({
    this.color = Colors.blue,
    this.strokeColor = Colors.white,
    this.strokeWidth = 4,
    Key? key,
  }) : super(key: key);

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
        shape: BoxShape.circle
      )
    );
  }
}