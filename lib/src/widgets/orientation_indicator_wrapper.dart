import 'dart:math';

import 'package:flutter/material.dart';


/// The rotation/orientation will implicitly animate whenever it changes.

class OrientationIndicatorWrapper extends ImplicitlyAnimatedWidget {
  /// The value is expected to be in radians.

  final double orientation;

  /// Size as radius in pixel of the orientation widget.

  final double radius;

  /// An custom widget that will replace the default indicator.

  final Widget child;

  const OrientationIndicatorWrapper({
    required this.child,
    this.radius = 40,
    this.orientation = 0,
    Key? key,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) : assert(radius > 0),
       super(key: key, duration: duration, curve: curve);

   @override
  _OrientationIndicatorWrapperState createState() => _OrientationIndicatorWrapperState();
}


class _OrientationIndicatorWrapperState extends AnimatedWidgetBaseState<OrientationIndicatorWrapper> {
  RotationTween? _rotationTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _rotationTween = visitor(
      _rotationTween,
      widget.orientation,
      (value) => RotationTween(begin: value)
    ) as RotationTween;
  }

  @override
  Widget build(context) {
    return Transform.rotate(
      alignment: Alignment.center,
      angle: _rotationTween?.evaluate(animation) ?? _rotationTween?.begin ?? 0,
      child: SizedBox.fromSize(
        size: Size.fromRadius(widget.radius),
        child: widget.child
      ),
    );
  }
}


/// Interpolate radians values in the direction of the shortest rotation delta / rotation angle.

class RotationTween extends Tween<double> {
  static const piDoubled = pi * 2;

  RotationTween({ double? begin, double? end }) : super(begin: begin, end: end);

  @override
  double lerp(double t) {
    // thanks to https://stackoverflow.com/questions/2708476/rotation-interpolation
    double rotationDelta = ((end! - begin!) + pi) % piDoubled - pi;
    return begin! + rotationDelta * t;
  }
}