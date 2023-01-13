import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '/src/widgets/accuracy_indicator_wrapper.dart';
import '/src/widgets/orientation_indicator_wrapper.dart';
import '/src/widgets/accuracy_indicator.dart';
import '/src/widgets/location_indicator.dart';
import '/src/widgets/orientation_indicator.dart';


class AnimatedLocationLayer extends StatefulWidget {

  /// The time interval in which new location data should be fetched.

  final Duration locationUpdateInterval;

  /// The time interval in which new sensor data should be fetched.

  final Duration orientationUpdateInterval;

  /// The minimal distance difference in meters of the new and the previous position that will be detected as a change.

  final int locationDifferenceThreshold;

  /// The minimal difference in radians of the new and the previous orientation that will be detected as a change.

  final double orientationDifferenceThreshold;

  /// The minimal difference in meters of the new and the previous accuracy that will be detected as a change.

  final double accuracyDifferenceThreshold;

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
    this.orientationUpdateInterval = const Duration(milliseconds: 200),
    this.locationDifferenceThreshold = 1,
    this.orientationDifferenceThreshold = 0.1,
    this.accuracyDifferenceThreshold = 0.5,
    this.locationIndicator = const LocationIndicator(),
    this.accuracyIndicator = const AccuracyIndicator(),
    this.orientationIndicator = const OrientationIndicator(),
    this.locationAnimationDuration = const Duration(milliseconds: 1500),
    this.accuracyAnimationDuration = const Duration(milliseconds: 600),
    this.orientationAnimationDuration = const Duration(milliseconds: 600),
    this.locationAnimationCurve = Curves.linear,
    this.orientationAnimationCurve = Curves.ease,
    this.accuracyAnimationCurve = Curves.ease,
  }) : super(key: key);

  @override
  State<AnimatedLocationLayer> createState() => _AnimatedLocationLayerState();
}


class _AnimatedLocationLayerState extends State<AnimatedLocationLayer> with SingleTickerProviderStateMixin {
  static const _piDoubled = 2 * pi;

  static const _earthCircumference = _piDoubled * earthRadius;

  LatLng? _location;

  double _accuracy = 0;

  double? _orientation;

  late FlutterMapState _map;

  StreamSubscription<Position>? _locationStreamSub;
  StreamSubscription<SensorEvent>? _orientationStreamSub;

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
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    _positionAnimationController.duration = widget.locationAnimationDuration;
    _positionAnimation.curve = widget.locationAnimationCurve;

    _cleanupStreams();
    _setupStreams();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _map = FlutterMapState.maybeOf(context)!;
  }


  @override
  Widget build(BuildContext context) {
    if (_positionTween == null || !_isVisible) {
      return const SizedBox.shrink();
    }

    return Flow(
      delegate: _FlowPositionDelegate(
        position: _positionTween!.animate(_positionAnimation),
        mapState: _map,
      ),
      children: [
        if (_accuracy > 0) AccuracyIndicatorWrapper(
          radius: _accuracy,
          scale: _scale,
          duration: widget.accuracyAnimationDuration,
          curve: widget.accuracyAnimationCurve,
          child: widget.accuracyIndicator,
        ),
        if (_orientation != null) OrientationIndicatorWrapper(
          orientation: _orientation!,
          duration: widget.orientationAnimationDuration,
          curve: widget.orientationAnimationCurve,
          child: widget.orientationIndicator,
        ),
        widget.locationIndicator,
      ],
    );
  }


  void _setupStreams() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (locationServiceEnabled) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _locationStreamSub = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            intervalDuration: widget.locationUpdateInterval,
            distanceFilter: widget.locationDifferenceThreshold,
          )
        ).listen(_handlePositionEvent, onError: (_) {});
      }
    }

    if (await SensorManager().isSensorAvailable(Sensors.ROTATION)) {
      final stream = await SensorManager().sensorUpdates(
        sensorId: Sensors.ROTATION,
        interval: widget.orientationUpdateInterval,
      );
      _orientationStreamSub = stream.listen(_handleAbsoluteOrientationEvent);
    }
  }


  void _cleanupStreams() {
    _locationStreamSub?.cancel();
    _orientationStreamSub?.cancel();
    _locationStreamSub = null;
    _orientationStreamSub = null;
  }


  void _updatePositionTween(LatLng location) {
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


  double get _scale => _location != null
    ? _calculateMetersPerPixel(_location!.latitude, _map.zoom) : 1;


  bool get _isVisible {
    if (_location == null || _positionTween == null) {
      return false;
    }

    final accuracyInPixel = _accuracy / _scale;

    final biggestSize = max(accuracyInPixel, 100);
    final positionInPixel = _map.project(_positionTween!.evaluate(_positionAnimation));
    final sw = CustomPoint(positionInPixel.x + biggestSize, positionInPixel.y - biggestSize);
    final ne = CustomPoint(positionInPixel.x - biggestSize, positionInPixel.y + biggestSize);

    return _map.pixelBounds.containsPartialBounds(Bounds(sw, ne));
  }


  void _handlePositionEvent(Position event) {
    _location = LatLng(event.latitude, event.longitude);
    _updatePositionTween(_location!);

    // don't update animation or rebuild widget when indicator is not visible in order to prevent repaints
    if (_isVisible) {
      _positionAnimationController
      ..value = 0.0
      ..forward();

      final newAccuracy = event.accuracy;
      // check if difference threshold is reached
      if ((_accuracy - newAccuracy).abs() > widget.accuracyDifferenceThreshold) {
        setState(() {
          _accuracy = newAccuracy;
        });
      }
    }
  }


  void _handleAbsoluteOrientationEvent(SensorEvent event) {
    double? newOrientation = 0;

    print(event.data);
    // don't rebuild widget when indicator is not visible in order to prevent repaints
    if (_isVisible) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // ios provides azimuth in degrees
        newOrientation = degToRadian(event.data.first);
      }
      else if (defaultTargetPlatform == TargetPlatform.android) {
        final g = event.data;
        final norm = sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2] + g[3] * g[3]);
        // normalize and set values to commonly known quaternion letter representatives
        final x = g[0] / norm;
        final y = g[1] / norm;
        final z = g[2] / norm;
        final w = g[3] / norm;
        // calc azimuth in radians
        final sinA = 2.0 * (w * z + x * y);
        final cosA = 1.0 - 2.0 * (y * y + z * z);
        final azimuth = atan2(sinA, cosA);
        // convert from [-pi, pi] to [0,2pi]
        newOrientation = (_piDoubled - azimuth) % _piDoubled;
      }
      print(newOrientation);


      // check if difference threshold is reached
      if (_orientation == null ||
        (_orientation! - newOrientation).abs() > widget.orientationDifferenceThreshold
      ) {
        setState(() {
          _orientation = newOrientation;
        });
      }
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


/// Flow-Delegate to position the indicators.

class _FlowPositionDelegate extends FlowDelegate {

  final Animation<LatLng> position;

  final FlutterMapState mapState;

  _FlowPositionDelegate({
    required this.position,
    required this.mapState,
  }) : super(repaint: position);


  @override
  bool shouldRepaint(_FlowPositionDelegate oldDelegate) {
    return position != oldDelegate.position ||
           mapState != oldDelegate.mapState;
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final absPixelPosition = mapState.project(position.value);
    final relPixelPosition = absPixelPosition - mapState.pixelOrigin;

    for (var i = 0; i < context.childCount; i++) {
      final halfChildSize = context.getChildSize(i)! / 2;
      final sw = CustomPoint(absPixelPosition.x + halfChildSize.width, absPixelPosition.y - halfChildSize.height);
      final ne = CustomPoint(absPixelPosition.x - halfChildSize.width, absPixelPosition.y + halfChildSize.height);
      // only render visible widgets
      if (mapState.pixelBounds.containsPartialBounds(Bounds(sw, ne))) {
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
