import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '/src/animated_location_controller.dart';
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

  /// Fires on real and interpolated orientation, location and accuracy value changes.

  final AnimatedLocationController? controller;

  const AnimatedLocationLayer({
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
    this.cameraTrackingMode = CameraTrackingMode.none,
    this.controller,
    super.key,
  });

  @override
  State<AnimatedLocationLayer> createState() => _AnimatedLocationLayerState();
}


class _AnimatedLocationLayerState extends State<AnimatedLocationLayer> with SingleTickerProviderStateMixin {
  static const _piDoubled = 2 * pi;

  static const _earthCircumference = _piDoubled * earthRadius;

  // TODO: Move interpolation and state entirely into the controller.
  // So the animation/interpolation is not done by the widgets and instead by the controller.
  // The widgets then simply consume these values.

  LatLng? _location;

  double _accuracy = 0;

  double? _orientation;

  AnimatedLocationController? _internalController;
  AnimatedLocationControllerImpl get _controller => (
      widget.controller
      ?? (_internalController ??= AnimatedLocationController())
    ) as AnimatedLocationControllerImpl;


  late MapCamera _mapCamera;

  StreamSubscription<Position>? _locationStreamSub;
  StreamSubscription<SensorEvent>? _orientationStreamSub;

  late final StreamSubscription<ServiceStatus> _serviceStatusStreamSub;

  @override
  void initState() {
    super.initState();
    _setupSensorStreams();

    _serviceStatusStreamSub = Geolocator.getServiceStatusStream().listen((event) {
      _cleanupSensorStreams();
      _setupSensorStreams();
    });


  }

  @override
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cleanupSensorStreams();
    _setupSensorStreams();

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapCamera = MapCamera.of(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return LocationIndicatorWrapper(
      position: _location!,
      duration: widget.locationAnimationDuration,
      curve: widget.locationAnimationCurve,
      controller: _controller,
      children: [
        if (_accuracy > 0) AccuracyIndicatorWrapper(
          radius: _accuracy,
          scale: _scale,
          duration: widget.accuracyAnimationDuration,
          curve: widget.accuracyAnimationCurve,
          controller: _controller,
          child: widget.accuracyIndicator,
        ),
        if (_orientation != null) OrientationIndicatorWrapper(
          orientation: _orientation!,
          duration: widget.orientationAnimationDuration,
          curve: widget.orientationAnimationCurve,
          controller: _controller,
          child: widget.orientationIndicator,
        ),
        widget.locationIndicator,
      ],
    );
  }


  void _setupSensorStreams() async {
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


  void _cleanupSensorStreams() {
    _locationStreamSub?.cancel();
    _orientationStreamSub?.cancel();
    _locationStreamSub = null;
    _orientationStreamSub = null;
  }

  double get _scale => _location != null
    ? _calculateMetersPerPixel(_location!.latitude, _mapCamera.zoom) : 1;


  bool get _isVisible {
    final location = _controller.location ?? _location;
    if (location == null) return false;
    final accuracyInPixel = _accuracy / _scale;
    final biggestSize = max(accuracyInPixel, 100);
    final positionInPixel = _mapCamera.project(location);
    final sw = CustomPoint(positionInPixel.x + biggestSize, positionInPixel.y - biggestSize);
    final ne = CustomPoint(positionInPixel.x - biggestSize, positionInPixel.y + biggestSize);

    return _mapCamera.pixelBounds.containsPartialBounds(Bounds(sw, ne));
  }


  void _handlePositionEvent(Position event) {
    setState(() {
      _location = LatLng(event.latitude, event.longitude);
    });

    final newAccuracy = event.accuracy;
    // check if difference threshold is reached
    if ((_accuracy - newAccuracy).abs() > widget.accuracyDifferenceThreshold) {
      setState(() {
        _accuracy = newAccuracy;
      });
    }
  }


  void _handleAbsoluteOrientationEvent(SensorEvent event) {
    final double newOrientation;

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
      else {
        newOrientation = 0;
      }

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
    _cleanupSensorStreams();
    _serviceStatusStreamSub.cancel();
    _internalController?.dispose();
    super.dispose();
  }
}
