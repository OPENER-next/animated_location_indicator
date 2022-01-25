import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:motion_sensors/motion_sensors.dart';

import '/src/animated_location_options.dart';
import '/src/widgets/accuracy_indicator_wrapper.dart';
import '/src/widgets/location_indicator_wrapper.dart';
import '/src/widgets/orientation_indicator_wrapper.dart';


class AnimatedLocationLayerWidget extends StatelessWidget {
  final AnimatedLocationOptions options;

  const AnimatedLocationLayerWidget({Key? key, required this.options}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mapState = MapState.maybeOf(context)!;
    return AnimatedLocationLayer(options, mapState, mapState.onMoved);
  }
}


class AnimatedLocationLayer extends StatefulWidget {
  final AnimatedLocationOptions options;
  final MapState map;
  // ignore: prefer_void_to_null
  final Stream<Null>? stream;

  AnimatedLocationLayer(this.options, this.map, this.stream)
      : super(key: options.key);

  @override
  State<AnimatedLocationLayer> createState() => _AnimatedLocationLayerState();
}


class _AnimatedLocationLayerState extends State<AnimatedLocationLayer> with SingleTickerProviderStateMixin {
  static const piDoubled = 2 * pi;

  static const earthCircumference = piDoubled * earthRadius;

  Position? position;

  double? orientation;

  double scale = 1;

  StreamSubscription<void>? mapStreamSub;
  StreamSubscription<Position>? locationStreamSub;
  StreamSubscription<AbsoluteOrientationEvent>? orientationStreamSub;

  late final positionAnimationController = AnimationController(
    vsync: this,
    duration: widget.options.locationAnimationDuration
  );

  late final positionAnimation = CurvedAnimation(
    parent: positionAnimationController,
    curve: widget.options.locationAnimationCurve
  );

  // animate over lat long because pixels are affected by zoom due to projection
  LatLngTween? positionTween;

  @override
  void initState() {
    super.initState();

    _setupStreams();
  }


  @override
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    positionAnimationController.duration = widget.options.locationAnimationDuration;
    positionAnimation.curve = widget.options.locationAnimationCurve;

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
          animation: positionAnimation,
          builder: (context, child) {
            if (positionTween == null || _isHidden()) {
              return const SizedBox.shrink();
            }
            final relativePixelPosition =
              widget.map.project(positionTween!.evaluate(positionAnimation)) - widget.map.getPixelOrigin();
            return Transform.translate(
              filterQuality: FilterQuality.none,
              offset: Offset(
                relativePixelPosition.x.toDouble(),
                relativePixelPosition.y.toDouble()
              ),
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              if ((position?.accuracy ?? 0) > 0) AccuracyIndicatorWrapper(
                radius: position!.accuracy,
                scale: scale,
                child: widget.options.accuracyIndicator,
                duration: widget.options.accuracyAnimationDuration,
                curve: widget.options.accuracyAnimationCurve
              ),
              if (orientation != null) OrientationIndicatorWrapper(
                orientation: orientation!,
                radius: widget.options.orientationIndicatorRadius,
                child: widget.options.orientationIndicator,
                duration: widget.options.orientationAnimationDuration,
                curve: widget.options.orientationAnimationCurve
              ),
              LocationIndicatorWrapper(
                radius: widget.options.locationIndicatorRadius,
                child: widget.options.locationIndicator,
              )
            ],
          )
        )
      )
    );
  }


  void _setupStreams() async {
    // map event stream
    mapStreamSub = widget.stream?.listen(_handleMapEvent);

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      locationStreamSub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          intervalDuration: widget.options.locationUpdateInterval
        )
      ).listen(_handlePositionEvent, onError: (_) {});
    }

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
      motionSensors.absoluteOrientationUpdateInterval = widget.options.orientationUpdateInterval.inMicroseconds;
      // TODO: not working probably due to bug in motion sensor package
      orientationStreamSub = motionSensors.absoluteOrientation.listen(
        _handleAbsoluteOrientationEvent
      );
    }
  }


  void _cleanupStreams() {
    mapStreamSub?.cancel();
    locationStreamSub?.cancel();
    orientationStreamSub?.cancel();
    mapStreamSub = null;
    locationStreamSub = null;
    orientationStreamSub = null;
  }


  void _updatePositionTween(Position position) {
    final location = LatLng(position.latitude, position.longitude);
    // set first position without animating
    if (positionTween == null) {
      positionTween = LatLngTween(begin: location, end: location);
    }
    // animate between new and previous position
    else {
      positionTween!
      ..begin = positionTween!.evaluate(positionAnimation)
      ..end = location;
    }
  }


  void _updateScale(Position? position) {
    if (position == null) {
      scale = 1;
    }
    else {
      scale = _calculateMetersPerPixel(position.latitude, widget.map.zoom);
    }
  }


  // calculates the indicator pixel position based on its size and location
  // returns true if the indicator is outside the viewport or no location is available
  bool _isHidden() {
    if (position != null && positionTween != null) {
      final accuracyInPixel = position!.accuracy / scale;

      final maxRadius = [
        accuracyInPixel,
        widget.options.locationIndicatorRadius,
        widget.options.orientationIndicatorRadius
      ].reduce(max);

      final positionInPixel = widget.map.project(positionTween!.evaluate(positionAnimation));
      final sw = CustomPoint(positionInPixel.x + maxRadius, positionInPixel.y - maxRadius);
      final ne = CustomPoint(positionInPixel.x - maxRadius, positionInPixel.y + maxRadius);

      return !widget.map.pixelBounds.containsPartialBounds(Bounds(sw, ne));
    }
    return true;
  }


  void _handleMapEvent(void event) {
    _updateScale(position);

    if (!_isHidden()) {
      setState(() { });
    }
  }


  void _handlePositionEvent(Position event) {
    position = event;

    _updateScale(position);
    _updatePositionTween(position!);

    if (!_isHidden()) {
      positionAnimationController
      ..value = 0.0
      ..forward();

      setState(() { });
    }
  }


  void _handleAbsoluteOrientationEvent(AbsoluteOrientationEvent event) {
    // convert from [-pi, pi] to [0,2pi]
    orientation = (piDoubled - event.yaw) % piDoubled;

    if (!_isHidden()) {
      setState(() { });
    }
  }


  double _calculateMetersPerPixel(double latitude, double zoomLevel) {
    final latitudeRadians = latitude * (pi/180);
    return earthCircumference * cos(latitudeRadians) / pow(2, zoomLevel + 8);
  }


  @override
  void dispose() {
    super.dispose();
    positionAnimationController.dispose();
    positionAnimation.dispose();
    _cleanupStreams();
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
