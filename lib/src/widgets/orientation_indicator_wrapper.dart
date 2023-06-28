import 'dart:math';

import 'package:flutter/material.dart';


/// The rotation/orientation will implicitly animate whenever it changes.

class OrientationIndicatorWrapper extends ImplicitlyAnimatedWidget {
  /// The value is expected to be in radians.

  final double orientation;

  /// An custom widget that will replace the default indicator.

  final Widget child;

  const OrientationIndicatorWrapper({
    required this.child,
    this.orientation = 0,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.ease,
    super.key,
  });

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
      child: widget.child
    );
  }

}
