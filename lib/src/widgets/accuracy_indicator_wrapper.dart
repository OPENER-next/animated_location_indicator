import 'package:flutter/material.dart';

import '/src/animated_location_controller.dart';


/// The radius will implicitly animate whenever it changes.

class AccuracyIndicatorWrapper extends ImplicitlyAnimatedWidget {
  /// The scale of meters per pixel.

  final double scale;

  /// The value is expected to be in meters.

  final double radius;

  final AnimatedLocationControllerImpl controller;

  final Widget child;

  const AccuracyIndicatorWrapper({
    required this.radius,
    required this.child,
    required this.controller,
    this.scale = 1,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.ease,
    super.key,
  });

  @override
  AnimatedWidgetBaseState<AccuracyIndicatorWrapper> createState() => _AccuracyIndicatorWrapperState();
}


class _AccuracyIndicatorWrapperState extends AnimatedWidgetBaseState<AccuracyIndicatorWrapper> {
  Tween<double>? _sizeTween;

  double get _accuracy => _sizeTween?.evaluate(animation) ?? _sizeTween?.begin ?? 0;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _sizeTween = visitor(
      _sizeTween,
      widget.radius,
      (value) => Tween<double>(begin: value)
    ) as Tween<double>;
  }

  @override
  Widget build(context) {
    return SizedBox.fromSize(
      size: Size.fromRadius(_accuracy / widget.scale),
      child: widget.child,
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

  void _handleAnimation() => widget.controller.accuracy = _accuracy;
}
