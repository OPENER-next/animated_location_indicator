import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:motion_sensors/motion_sensors.dart';

import '/src/widgets/accuracy_indicator_wrapper.dart';
import '/src/widgets/location_indicator_wrapper.dart';
import '/src/widgets/orientation_indicator_wrapper.dart';
import '/src/widgets/accuracy_indicator.dart';
import '/src/widgets/location_indicator.dart';
import '/src/widgets/orientation_indicator.dart';


class AnimatedLocationLayer extends StatefulWidget {
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

  const AnimatedLocationLayer({
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
  }) : assert(orientationIndicatorRadius > 0),
       assert(locationIndicatorRadius > 0),
       super(key: key);

  @override
  State<AnimatedLocationLayer> createState() => _AnimatedLocationLayerState();
}


class _AnimatedLocationLayerState extends State<AnimatedLocationLayer> with SingleTickerProviderStateMixin {
  static const _piDoubled = 2 * pi;

  static const _earthCircumference = _piDoubled * earthRadius;

  Position? _position;

  double? _orientation;

  double _scale = 1;

  late FlutterMapState _map;

  StreamSubscription<Position>? _locationStreamSub;
  StreamSubscription<AbsoluteOrientationEvent>? _orientationStreamSub;

  late final _positionAnimationController = AnimationController(
    vsync: this,
    duration: widget.locationAnimationDuration
  );

  late final _positionAnimation = CurvedAnimation(
    parent: _positionAnimationController,
    curve: widget.locationAnimationCurve
  );

  // animate over lat long because pixels are affected by zoom due to projection
  LatLngTween? _positionTween;

  @override
  void initState() {
    super.initState();

    _setupStreams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _map = FlutterMapState.maybeOf(context)!;
  }

  @override
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    _positionAnimationController.duration = widget.locationAnimationDuration;
    _positionAnimation.curve = widget.locationAnimationCurve;

    _cleanupStreams();
    _setupStreams();
  }


  @override
  Widget build(BuildContext context) {
    return FractionalTranslation(
      // set location indicator origin to center
      translation: const Offset(-0.5, -0.5),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _positionAnimation,
          builder: (context, child) {
            if (_positionTween == null || _isHidden()) {
              return const SizedBox.shrink();
            }
            final relativePixelPosition = _map.project(_positionTween!.evaluate(_positionAnimation)) - _map.pixelOrigin;
            return Transform.translate(
              filterQuality: FilterQuality.none,
              offset: Offset(
                relativePixelPosition.x.toDouble(),
                relativePixelPosition.y.toDouble(),
              ),
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              if ((_position?.accuracy ?? 0) > 0) AccuracyIndicatorWrapper(
                radius: _position!.accuracy,
                scale: _scale,
                duration: widget.accuracyAnimationDuration,
                curve: widget.accuracyAnimationCurve,
                child: widget.accuracyIndicator,
              ),
              if (_orientation != null) OrientationIndicatorWrapper(
                orientation: _orientation!,
                radius: widget.orientationIndicatorRadius,
                duration: widget.orientationAnimationDuration,
                curve: widget.orientationAnimationCurve,
                child: widget.orientationIndicator,
              ),
              LocationIndicatorWrapper(
                radius: widget.locationIndicatorRadius,
                child: widget.locationIndicator,
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _setupStreams() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (locationServiceEnabled) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _locationStreamSub = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            intervalDuration: widget.locationUpdateInterval
          )
        ).listen(_handlePositionEvent, onError: (_) {});
      }
    }

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      motionSensors.absoluteOrientationUpdateInterval = widget.orientationUpdateInterval.inMicroseconds;
      // TODO: not working probably due to bug in motion sensor package
      _orientationStreamSub = motionSensors.absoluteOrientation.listen(
        _handleAbsoluteOrientationEvent
      );
    }
  }


  void _cleanupStreams() {
    _locationStreamSub?.cancel();
    _orientationStreamSub?.cancel();
    _locationStreamSub = null;
    _orientationStreamSub = null;
  }


  void _updatePositionTween(Position position) {
    final location = LatLng(position.latitude, position.longitude);
    // set first position without animating
    if (_positionTween == null) {
      _positionTween = LatLngTween(begin: location, end: location);
    }
    // animate between new and previous position
    else {
      _positionTween!
      ..begin = _positionTween!.evaluate(_positionAnimation)
      ..end = location;
    }
  }


  void _updateScale(Position? position) {
    if (position == null) {
      _scale = 1;
    }
    else {
      _scale = _calculateMetersPerPixel(position.latitude, _map.zoom);
    }
  }


  // calculates the indicator pixel position based on its size and location
  // returns true if the indicator is outside the viewport or no location is available
  bool _isHidden() {
    if (_position != null && _positionTween != null) {
      final accuracyInPixel = _position!.accuracy / _scale;

      final maxRadius = [
        accuracyInPixel,
        widget.locationIndicatorRadius,
        widget.orientationIndicatorRadius
      ].reduce(max);

      final positionInPixel = _map.project(_positionTween!.evaluate(_positionAnimation));
      final sw = CustomPoint(positionInPixel.x + maxRadius, positionInPixel.y - maxRadius);
      final ne = CustomPoint(positionInPixel.x - maxRadius, positionInPixel.y + maxRadius);

      return !_map.pixelBounds.containsPartialBounds(Bounds(sw, ne));
    }
    return true;
  }


  void _handlePositionEvent(Position event) {
    _position = event;

    _updateScale(_position);
    _updatePositionTween(_position!);

    if (!_isHidden()) {
      _positionAnimationController
      ..value = 0.0
      ..forward();

      setState(() { });
    }
  }


  void _handleAbsoluteOrientationEvent(AbsoluteOrientationEvent event) {
    // convert from [-pi, pi] to [0,2pi]
    _orientation = (_piDoubled - event.yaw) % _piDoubled;

    if (!_isHidden()) {
      setState(() { });
    }
  }


  double _calculateMetersPerPixel(double latitude, double zoomLevel) {
    final latitudeRadians = latitude * (pi/180);
    return _earthCircumference * cos(latitudeRadians) / pow(2, zoomLevel + 8);
  }


  @override
  void dispose() {
    _positionAnimationController.dispose();
    _positionAnimation.dispose();
    _cleanupStreams();
    super.dispose();
  }
}


/// Interpolate latitude and longitude values.

class LatLngTween extends Tween<LatLng> {
  static const piDoubled = pi * 2;

  LatLngTween({ LatLng? begin, LatLng? end }) : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    // latitude varies from [90, -90]
    // longitude varies from [180, -180]

    final latitudeDelta = end!.latitude - begin!.latitude;
    final latitude = begin!.latitude + latitudeDelta * t;

    // calculate longitude in range of [0 - 360]
    final longitudeDelta = _wrapDegrees(end!.longitude - begin!.longitude);
    var longitude = begin!.longitude + longitudeDelta * t;
    // wrap back to [180, -180]
    longitude = _wrapDegrees(longitude);

    return LatLng(latitude, longitude);
  }

  double _wrapDegrees(v) => (v + 180) % 360 - 180;
}
