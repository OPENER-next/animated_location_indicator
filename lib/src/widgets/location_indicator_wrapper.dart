import 'package:flutter/material.dart';


class LocationIndicatorWrapper extends StatelessWidget {
  /// Size as radius in pixel of the location widget.

  final double radius;

  final Widget child;

  const LocationIndicatorWrapper({
    required this.child,
    this.radius = 10,
    Key? key
  }) : super(key: key);

  @override
  Widget build(context) {
    return SizedBox.fromSize(
      size: Size.fromRadius(radius),
      child: child
    );
  }
}