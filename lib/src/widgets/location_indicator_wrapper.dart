import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart';

import '/src/animated_location_controller.dart';
import '/src/animation/latlng_tween.dart';


typedef LocationAnimationUpdate = void Function(BuildContext context, LatLng position);


/// The rotation/orientation will implicitly animate whenever it changes.

class LocationIndicatorWrapper extends ImplicitlyAnimatedWidget {
  /// The value is expected to be in radians.

  final LatLng position;

  /// An custom widget that will replace the default indicator.

  final List<Widget> children;

  final AnimatedLocationControllerImpl controller;

  const LocationIndicatorWrapper({
    required this.children,
    required this.position,
    required this.controller,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.ease,
    super.key,
  });

   @override
  _LocationIndicatorWrapperState createState() => _LocationIndicatorWrapperState();
}


class _LocationIndicatorWrapperState extends AnimatedWidgetBaseState<LocationIndicatorWrapper> {
  // animate over lat long because pixels are affected by zoom due to projection
  LatLngTween? _positionTween;

  LatLng get _position => _positionTween?.evaluate(animation) ?? _positionTween!.begin!;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _positionTween = visitor(
      _positionTween,
      widget.position,
      (value) => LatLngTween(begin: value)
    ) as LatLngTween;
  }

  @override
  Widget build(context) {
    return Flow(
      delegate: _FlowPositionDelegate(
        position: _positionTween!.animate(animation),
        mapCamera: MapCamera.of(context),
      ),
      children: widget.children,
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

  void _handleAnimation() => widget.controller.location = _position;
}


/// Flow-Delegate to position the indicators.

class _FlowPositionDelegate extends FlowDelegate {

  final Animation<LatLng> position;

  final MapCamera mapCamera;

  _FlowPositionDelegate({
    required this.position,
    required this.mapCamera,
  }) : super(repaint: position);


  @override
  bool shouldRepaint(_FlowPositionDelegate oldDelegate) {
    return position != oldDelegate.position ||
           mapCamera != oldDelegate.mapCamera;
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final absPixelPosition = mapCamera.project(position.value);
    final relPixelPosition = absPixelPosition - mapCamera.pixelOrigin.toDoublePoint();

    for (var i = 0; i < context.childCount; i++) {
      final halfChildSize = context.getChildSize(i)! / 2;
      final sw = Point(absPixelPosition.x + halfChildSize.width, absPixelPosition.y - halfChildSize.height);
      final ne = Point(absPixelPosition.x - halfChildSize.width, absPixelPosition.y + halfChildSize.height);
      // only render visible widgets
      if (mapCamera.pixelBounds.containsPartialBounds(Bounds(sw, ne))) {
        context.paintChild(i,
          transform: Matrix4.translationValues(
            // center all widgets
            relPixelPosition.x - halfChildSize.width,
            relPixelPosition.y - halfChildSize.height,
            0,
          ),
        );
      }
    }
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    // set constraints to infinity in order to allow the children (like the accuracy circle)
    // to size themselves bigger than the constraints passed from the outside (usually the screen size)
    return const BoxConstraints(
      maxHeight: double.infinity,
      maxWidth: double.infinity,
    );
  }
}
