import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '/src/animated_location_controller.dart';
import '/src/widgets/location_indicator_wrapper.dart';
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

  /// Defines if and how the camera should follow the user.
  final CameraTrackingMode cameraTrackingMode;

  /// Fires on orientation, location and accuracy value changes.

  final AnimatedLocationController? controller;

  const AnimatedLocationLayer({
    this.locationIndicator = const LocationIndicator(),
    this.accuracyIndicator = const AccuracyIndicator(),
    this.orientationIndicator = const OrientationIndicator(),
    this.cameraTrackingMode = CameraTrackingMode.none,
    this.controller,
    super.key,
  });

  @override
  State<AnimatedLocationLayer> createState() => _AnimatedLocationLayerState();
}


class _AnimatedLocationLayerState extends State<AnimatedLocationLayer> with TickerProviderStateMixin {
  AnimatedLocationController? _internalController;
  AnimatedLocationController get _controller =>
      widget.controller
      ?? (_internalController ??= AnimatedLocationController(vsync: this));

  MapCamera get _mapCamera => MapCamera.of(context);

  @override
  void initState() {
    super.initState();
    _controller.animatedLocation.addListener(_updateCamera);
    _controller.animatedOrientation.addListener(_updateCamera);
  }

  @override
  void didUpdateWidget(covariant AnimatedLocationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final oldController = oldWidget.controller ?? _internalController;
      if (oldController != null) {
        _controller.animatedLocation.removeListener(_updateCamera);
        _controller.animatedOrientation.removeListener(_updateCamera);
      }
      _controller.animatedLocation.addListener(_updateCamera);
      _controller.animatedOrientation.addListener(_updateCamera);
    }
    if (widget.cameraTrackingMode != oldWidget.cameraTrackingMode &&
        widget.cameraTrackingMode != CameraTrackingMode.none
    ) {
      // immediately enforce camera tracking without waiting for a new position change
      // if there's a current frame wait for the end of that frame.
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        SchedulerBinding.instance.endOfFrame.then((_) => _updateCamera);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LocationIndicatorWrapper(
      position: _controller.animatedLocation,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _controller.animatedAccuracy,
          builder: (context, value, child) => _controller.accuracy > 0
            ? SizedBox.square(
              dimension: value / _scale,
              child: child,
            )
            : const SizedBox.shrink(),
          child: widget.accuracyIndicator,
        ),
        ValueListenableBuilder<double>(
          valueListenable: _controller.animatedOrientation,
          builder: (context, value, child) => _controller.orientation != null
            ? Transform.rotate(
              angle: value,
              child: child,
            )
            : const SizedBox.shrink(),
          child: widget.orientationIndicator,
        ),
        widget.locationIndicator,
      ],
    );
  }


  double get _scale => _controller.animatedLocation.value != null
    ? _calculateMetersPerPixel(_controller.animatedLocation.value!.latitude, _mapCamera.zoom) : 1;

  /// Handles camera position and rotation updates when the AnimatedLocationController changes.
  ///
  /// Should only be called via a ticker/animation so it is not fired while rendering a frame.

  void _updateCamera() async {
    if (!mounted) return;
    final controller = MapController.of(context);

    if (widget.cameraTrackingMode == CameraTrackingMode.locationAndOrientation &&
        _controller.animatedLocation.value != null &&
        _controller.orientation != null
    ) {
      // (counter) rotate map so the map faces always the direction the user is facing
      controller.moveAndRotate(
        _controller.animatedLocation.value!,
        _mapCamera.zoom,
        _controller.animatedOrientation.value * (-180/pi),
        id: 'AnimatedLocationLayerCameraTracking',
      );
    }
    else if (widget.cameraTrackingMode == CameraTrackingMode.location &&
             _controller.animatedLocation.value != null
    ) {
      controller.move(
        _controller.animatedLocation.value!,
        _mapCamera.zoom,
        id: 'AnimatedLocationLayerCameraTracking',
      );
    }
    else if (widget.cameraTrackingMode == CameraTrackingMode.orientation &&
             _controller.orientation != null
    ) {
      // (counter) rotate map so the map faces always the direction the user is facing
      controller.rotate(
        _controller.animatedOrientation.value * (-180/pi),
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
    _controller.animatedLocation.removeListener(_updateCamera);
    _controller.animatedOrientation.removeListener(_updateCamera);
    _internalController?.dispose();
    super.dispose();
  }
}
