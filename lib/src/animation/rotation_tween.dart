import 'dart:math';

import 'package:flutter/animation.dart';

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
