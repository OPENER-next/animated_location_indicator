import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';

import '/src/widgets/accuracy_indicator.dart';
import '/src/widgets/orientation_indicator.dart';
import '/src/widgets/location_indicator.dart';

class AnimatedLocationOptions extends LayerOptions {
  /// The time interval in which new location data should be fetched.

  final Duration locationUpdateInterval;

  /// The time interval in which new sensor data should be fetched.

  final Duration orientationUpdateInterval;

  /// The radius in pixel of the location indicator.

  final double locationIndicatorRadius;

  /// The radius in pixel of the orientation indicator.

  final double orientationIndicatorRadius;

  /// A custom location indicator widget that replaces the default.

  final Widget locationIndicator;

  /// A custom orientation indicator widget that replaces the default.

  final Widget orientationIndicator;

  /// A custom accuracy indicator widget that replaces the default.

  final Widget accuracyIndicator;

  /// The duration of the location change transition.

  final Duration locationAnimationDuration;

  /// The curve used for the location change transition.

  final Curve locationAnimationCurve;

  /// The duration of the orientation change transition.

  final Duration orientationAnimationDuration;

  /// The curve used for the orientation change transition.

  final Curve orientationAnimationCurve;

  /// The duration of the accuracy change transition.

  final Duration accuracyAnimationDuration;

  /// The curve used for the accuracy change transition.

  final Curve accuracyAnimationCurve;

  AnimatedLocationOptions({
    Key? key,
    this.locationUpdateInterval = const Duration(milliseconds: 1000),
    this.orientationUpdateInterval = const Duration(milliseconds: 500),
    this.locationIndicatorRadius = 10,
    this.orientationIndicatorRadius = 40,
    this.locationIndicator = const LocationIndicator(),
    this.accuracyIndicator = const AccuracyIndicator(),
    this.orientationIndicator = const OrientationIndicator(),
    this.locationAnimationDuration = const Duration(milliseconds: 1500),
    this.accuracyAnimationDuration = const Duration(milliseconds: 600),
    this.orientationAnimationDuration = const Duration(milliseconds: 600),
    this.locationAnimationCurve = Curves.linear,
    this.orientationAnimationCurve = Curves.ease,
    this.accuracyAnimationCurve = Curves.ease,
    Stream<Null>? rebuild,
  }) : assert(orientationIndicatorRadius > 0),
       assert(locationIndicatorRadius > 0),
       super(key: key, rebuild: rebuild);
}