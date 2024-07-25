import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/src/animated_location_controller.dart';
import '/src/widgets/accuracy_indicator_wrapper.dart';
import '/src/widgets/location_indicator_wrapper.dart';
import '/src/widgets/orientation_indicator_wrapper.dart';
import '/src/widgets/accuracy_indicator.dart';
import '/src/widgets/location_indicator.dart';
import '/src/widgets/orientation_indicator.dart';


enum CameraTrackingMode {
  /// The map camera won't follow the user's location.
  none,
  /// The map camera will follow the user's location.
  location,
  /// The map camera will rotate according the user's orientation.
  orientation,
  /// The map camera will follow the user's location and rotate according the user's orientation.
  locationAndOrientation,
}


class AnimatedLocationLayer extends StatefulWidget {

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

  /// Defines if and how the camera should follow the user.
  final CameraTrackingMode cameraTrackingMode;

  /// Fires on real and interpolated orientation, location and accuracy value changes.

  final AnimatedLocationController? controller;

  const AnimatedLocationLayer({
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
  AnimatedLocationController? _internalController;
  AnimatedLocationControllerImpl get _controller => (
      widget.controller
      ?? (_internalController ??= AnimatedLocationController())
    ) as AnimatedLocationControllerImpl;


  MapCamera get _mapCamera => MapCamera.of(context);

  @override
  void initState() {
    super.initState();
    _controller.addRawListener(_updateIndicator);
    _controller.addListener(_updateCamera);
  }

  @override
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final oldController = oldWidget.controller ?? _internalController;
      if (oldController != null) {
        oldController.removeListener(_updateCamera);
        oldController.removeRawListener(_updateIndicator);
      }
      _controller.addListener(_updateCamera);
      _controller.addRawListener(_updateIndicator);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isActive || !_isVisible) return const SizedBox.shrink();

    return MobileLayerTransformer(
      child: LocationIndicatorWrapper(
        position: _controller.rawLocation!,
        duration: widget.locationAnimationDuration,
        curve: widget.locationAnimationCurve,
        controller: _controller,
        children: [
          if (_controller.rawAccuracy > 0) AccuracyIndicatorWrapper(
            radius: _controller.rawAccuracy,
            scale: _scale,
            duration: widget.accuracyAnimationDuration,
            curve: widget.accuracyAnimationCurve,
            controller: _controller,
            child: widget.accuracyIndicator,
          ),
          if (_controller.rawOrientation != null) OrientationIndicatorWrapper(
            orientation: _controller.rawOrientation!,
            duration: widget.orientationAnimationDuration,
            curve: widget.orientationAnimationCurve,
            controller: _controller,
            child: widget.orientationIndicator,
          ),
          widget.locationIndicator,
        ],
      ),
    );
  }


  double get _scale => _controller.rawLocation != null
    ? _calculateMetersPerPixel(_controller.rawLocation!.latitude, _mapCamera.zoom) : 1;


  bool get _isVisible {
    final location = _controller.location ?? _controller.rawLocation;
    if (location == null) return false;
    final accuracyInPixel = _controller.accuracy / _scale;
    final biggestSize = max(accuracyInPixel, 100);
    final positionInPixel = _mapCamera.project(location);
    final sw = Point(positionInPixel.x + biggestSize, positionInPixel.y - biggestSize);
    final ne = Point(positionInPixel.x - biggestSize, positionInPixel.y + biggestSize);
    return _mapCamera.pixelBounds.containsPartialBounds(Bounds(sw, ne));
  }

  void _updateIndicator() {
    setState(() {});
  }

  /// Handles camera position and rotation updates when the AnimatedLocationController changes

  void _updateCamera() async {
    // if there's a current frame wait for the end of that frame.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final controller = MapController.of(context);

    if (widget.cameraTrackingMode == CameraTrackingMode.locationAndOrientation &&
        _controller.location != null &&
        _controller.orientation != null
    ) {
      // (counter) rotate map so the map faces always the direction the user is facing
      controller.moveAndRotate(
        _controller.location!,
        _mapCamera.zoom,
        _controller.orientation! * (-180/pi),
        id: 'AnimatedLocationLayerCameraTracking',
      );
    }
    else if (widget.cameraTrackingMode == CameraTrackingMode.location &&
             _controller.location != null
    ) {
      controller.move(
        _controller.location!,
        _mapCamera.zoom,
        id: 'AnimatedLocationLayerCameraTracking',
      );
    }
    else if (widget.cameraTrackingMode == CameraTrackingMode.orientation &&
             _controller.orientation != null
    ) {
      // (counter) rotate map so the map faces always the direction the user is facing
      controller.rotate(
        _controller.orientation! * (-180/pi),
        id: 'AnimatedLocationLayerCameraTracking',
      );
    }
  }

  double _calculateMetersPerPixel(double latitude, double zoomLevel) {
    const piDoubled = 2 * pi;
    const earthCircumference = piDoubled * earthRadius;

    final latitudeRadians = latitude * (pi/180);
    return earthCircumference * cos(latitudeRadians) / pow(2, zoomLevel + 8);
  }


  @override
  void dispose() {
    _controller.removeRawListener(_updateIndicator);
    _controller.removeListener(_updateCamera);
    _internalController?.dispose();
    super.dispose();
  }
}
