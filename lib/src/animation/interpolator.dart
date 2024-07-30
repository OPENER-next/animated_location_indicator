import 'package:flutter/animation.dart';


class Interpolator<T> extends Animation<T> with AnimationWithParentMixin {
  final AnimationController _controller;
  late final CurvedAnimation _animation;
  final Tween<T> _tween;

  Interpolator({
    required TickerProvider vsync,
    required Tween<T> tween,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.ease,
  }) :
  _tween = tween,
  _controller = AnimationController(
    duration: duration,
    vsync: vsync,
  ) {
    _animation = CurvedAnimation(
      parent: _controller,
      curve: curve,
    );
  }

  set value(T targetValue) {
    if (_shouldAnimateTween(targetValue)) {
      _updateTween(targetValue);
      _controller
        ..value = 0.0
        ..forward();
    }
    else {
      _tween.end ??= _tween.begin;
    }
  }

  @override
  T get value => _tween.evaluate(_animation);

  @override
  Animation get parent => _controller;

  bool _shouldAnimateTween(T targetValue) {
    return targetValue != (_tween.end ?? _tween.begin);
  }

  void _updateTween(T targetValue) {
    _tween
      ..begin = _tween.evaluate(_animation)
      ..end = targetValue;
  }

  void dispose() {
    _animation.dispose();
    _controller.dispose();
  }
}
