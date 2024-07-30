import 'dart:async';
import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'animation/interpolator.dart';
import 'animation/latlng_tween.dart';
import 'animation/rotation_tween.dart';


/// Can be used to retrieve the underlying values (real and interpolated) that drive the indicators.
///
/// Notifies whenever `location`, `accuracy`, `orientation` or `isActive` changes.
///
/// The animated values can be accessed via `animatedOrientation`, `animatedAccuracy`, `animatedOrientation`.
///
/// **Note:** vsync should be a multi ticker provider like `TickerProviderStateMixin`.

class AnimatedLocationController extends ChangeNotifier {

  StreamSubscription<Position>? _locationStreamSub;
  StreamSubscription<SensorEvent>? _orientationStreamSub;

  late final StreamSubscription<ServiceStatus> _serviceStatusStreamSub;

  final Interpolator<LatLng?> _animatedLocation;
  final Interpolator<double> _animatedAccuracy;
  final Interpolator<double> _animatedOrientation;

  AnimatedLocationController({
    required TickerProvider vsync,
    Duration locationUpdateInterval = const Duration(milliseconds: 1000),
    Duration orientationUpdateInterval = const Duration(milliseconds: 200),
    int locationDifferenceThreshold = 1,
    double orientationDifferenceThreshold = 0.1,
    double accuracyDifferenceThreshold = 0.5,
    /// The duration of the location change transition.
    Duration locationAnimationDuration = const Duration(milliseconds: 1500),
    /// The duration of the accuracy change transition.
    Duration accuracyAnimationDuration = const Duration(milliseconds: 600),
    /// The duration of the orientation change transition.
    Duration orientationAnimationDuration = const Duration(milliseconds: 600),
    /// The curve used for the location change transition.
    Curve locationAnimationCurve = Curves.linear,
    /// The curve used for the orientation change transition.
    Curve orientationAnimationCurve = Curves.ease,
    /// The curve used for the accuracy change transition.
    Curve accuracyAnimationCurve = Curves.ease
  }) :
    _animatedLocation = Interpolator(
      vsync: vsync,
      tween: LatLngTween(),
      duration: locationAnimationDuration,
      curve: locationAnimationCurve,
    ),
    _animatedAccuracy = Interpolator(
      vsync: vsync,
      tween: Tween<double>(begin: 0, end: 0),
      duration: accuracyAnimationDuration,
      curve: accuracyAnimationCurve,
    ),
    _animatedOrientation = Interpolator(
      vsync: vsync,
      tween: RotationTween(begin: 0, end: 0),
      duration: orientationAnimationDuration,
      curve: orientationAnimationCurve,
    ),
    _locationUpdateInterval = locationUpdateInterval,
    _orientationUpdateInterval = orientationUpdateInterval,
    _locationDifferenceThreshold = locationDifferenceThreshold,
    _orientationDifferenceThreshold = orientationDifferenceThreshold,
    _accuracyDifferenceThreshold = accuracyDifferenceThreshold
  {
    activate();

    _serviceStatusStreamSub = Geolocator.getServiceStatusStream().listen((event) {
      if (event == ServiceStatus.enabled) {
        activate();
      }
      else {
        deactivate();
      }
    });
  }

  bool get isActive => _locationStreamSub != null;

  void activate() {
    if (isActive) deactivate();
    _setupLocationStream();
    _setupRotationSensorStream();
    notifyListeners();
  }

  void deactivate() {
    _cleanupLocationStream();
    _cleanupRotationSensorStream();
    notifyListeners();
  }

  Duration _locationUpdateInterval;
  /// The time interval in which new location data should be fetched.
  Duration get locationUpdateInterval => _locationUpdateInterval;
  set locationUpdateInterval(Duration value) {
    if (value != _locationUpdateInterval) {
      _locationUpdateInterval = value;
      _cleanupLocationStream();
      _setupLocationStream();
    }
  }

  Duration _orientationUpdateInterval;
  /// The time interval in which new sensor data should be fetched.
  Duration get orientationUpdateInterval => _orientationUpdateInterval;
  set orientationUpdateInterval(Duration value) {
    if (value != _orientationUpdateInterval) {
      _orientationUpdateInterval = value;
      _cleanupRotationSensorStream();
      _setupRotationSensorStream();
    }
  }

  int _locationDifferenceThreshold;
  /// The minimal distance difference in meters of the new and the previous position that will be detected as a change.
  int get locationDifferenceThreshold => _locationDifferenceThreshold;
  set locationDifferenceThreshold(int value) {
    if (value != _locationDifferenceThreshold) {
      _locationDifferenceThreshold = value;
      _cleanupLocationStream();
      _setupLocationStream();
    }
  }

  double _orientationDifferenceThreshold;
  /// The minimal difference in radians of the new and the previous orientation that will be detected as a change.
  double get orientationDifferenceThreshold => _orientationDifferenceThreshold;
  set orientationDifferenceThreshold(double value) {
    if (value != _orientationDifferenceThreshold) {
      _orientationDifferenceThreshold = value;
      _cleanupRotationSensorStream();
      _setupRotationSensorStream();
    }
  }

  double _accuracyDifferenceThreshold;
  /// The minimal difference in meters of the new and the previous accuracy that will be detected as a change.
  double get accuracyDifferenceThreshold => _accuracyDifferenceThreshold;
  set accuracyDifferenceThreshold(double value) {
    if (value != _accuracyDifferenceThreshold) {
      _accuracyDifferenceThreshold = value;
      _cleanupLocationStream();
      _setupLocationStream();
    }
  }

  Animation<LatLng?> get animatedLocation => _animatedLocation;
  Animation<double> get animatedAccuracy => _animatedAccuracy;
  Animation<double> get animatedOrientation => _animatedOrientation;

  LatLng? _rawLocation;
  /// Location may be null if the location permissions aren't granted or the location service is turned of.
  LatLng? get location => _rawLocation;

  double _rawAccuracy = 0;
  double get accuracy => _rawAccuracy;

  double? _rawOrientation;
  /// Orientation may be null if the device doesn't provide the respective sensors.
  double? get orientation => _rawOrientation;

  // location methods

  void _setupLocationStream() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (locationServiceEnabled) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _locationStreamSub = _getPositionStream()
          .listen(_handlePositionEvent, onError: (_) => deactivate());
      }
    }
  }

  // required to chain streams together
  Stream<Position> _getPositionStream() async* {
    // used to forcefully get an initial position and not wait for an upcoming position event
    yield await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition();
    yield* Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        intervalDuration: locationUpdateInterval,
        distanceFilter: locationDifferenceThreshold,
      ),
    );
  }

  void _cleanupLocationStream() {
    _locationStreamSub?.cancel();
    _locationStreamSub = null;
  }

  void _handlePositionEvent(Position event) {
    _rawLocation = LatLng(event.latitude, event.longitude);
    _animatedLocation.value = _rawLocation!;

    final newAccuracy = event.accuracy;
    // check if difference threshold is reached
    if ((_rawAccuracy - newAccuracy).abs() > accuracyDifferenceThreshold) {
      _rawAccuracy = newAccuracy;
      _animatedAccuracy.value = newAccuracy;
    }
    notifyListeners();
  }

  // rotation sensor methods

  void _setupRotationSensorStream() async {
    if (await SensorManager().isSensorAvailable(Sensors.ROTATION)) {
      final stream = await SensorManager().sensorUpdates(
        sensorId: Sensors.ROTATION,
        interval: orientationUpdateInterval,
      );
      _orientationStreamSub = stream.listen(_handleAbsoluteOrientationEvent);
    }
  }

  void _cleanupRotationSensorStream() {
    _orientationStreamSub?.cancel();
    _orientationStreamSub = null;
  }

  void _handleAbsoluteOrientationEvent(SensorEvent event) {
    const piDoubled = 2 * pi;
    final double newOrientation;
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
      newOrientation = (piDoubled - azimuth) % piDoubled;
    }
    else {
      newOrientation = 0;
    }

    // check if difference threshold is reached
    if (_rawOrientation == null ||
      (_rawOrientation! - newOrientation).abs() > orientationDifferenceThreshold
    ) {
      _rawOrientation = newOrientation;
      _animatedOrientation.value = newOrientation;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _serviceStatusStreamSub.cancel();
    _animatedLocation.dispose();
    _animatedAccuracy.dispose();
    _animatedOrientation.dispose();
    deactivate();
    super.dispose();
  }
}
