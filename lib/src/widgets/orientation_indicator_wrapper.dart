import 'package:flutter/material.dart';

import '/src/animated_location_controller.dart';
import '/src/animation/rotation_tween.dart';

typedef OrientationAnimationUpdate = void Function(BuildContext context, double angle);


/// The rotation/orientation will implicitly animate whenever it changes.

class OrientationIndicatorWrapper extends ImplicitlyAnimatedWidget {
  /// The value is expected to be in radians.

  final double orientation;

  /// An custom widget that will replace the default indicator.

  final Widget child;

  final AnimatedLocationControllerImpl controller;

  const OrientationIndicatorWrapper({
    required this.child,
    required this.controller,
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

  double get _orientation => _rotationTween?.evaluate(animation) ?? _rotationTween?.begin ?? 0;

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
      angle: _orientation,
      child: widget.child
    );
  }

  @override
  void initState() {
    super.initState();
    animation.addListener(_handleAnimation);
  }

  @override
  void dispose() {
    animation.removeListener(_handleAnimation);
    super.dispose();
  }

  void _handleAnimation() => widget.controller.orientation = _orientation;
}
