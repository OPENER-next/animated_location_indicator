import 'package:flutter/material.dart';


/// The radius will implicitly animate whenever it changes.

class AccuracyIndicatorWrapper extends ImplicitlyAnimatedWidget {
  /// The scale of meters per pixel.

  final double scale;

  /// The value is expected to be in meters.

  final double radius;

  final Widget child;

  const AccuracyIndicatorWrapper({
    required this.radius,
    required this.child,
    this.scale = 1,
    Key? key,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) : super(key: key, duration: duration, curve: curve);

   @override
  _AccuracyIndicatorWrapperState createState() => _AccuracyIndicatorWrapperState();
}


class _AccuracyIndicatorWrapperState extends AnimatedWidgetBaseState<AccuracyIndicatorWrapper> {
  Tween<double>? _sizeTween;

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
      size: Size.fromRadius(
        (_sizeTween?.evaluate(animation) ?? _sizeTween?.begin ?? 0) / widget.scale
      ),
      child: widget.child
    );
  }
}