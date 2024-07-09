import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Can be used to retrieve the underlying values (real and interpolated) that drive the indicators.
///
/// Notifies whenever `location`, `accuracy`, `orientation` or `isActive` changes.
///
/// The uninterpolated values can be accessed via `rawOrientation`, `rawAccuracy`, `rawOrientation` and listened to via `addRawListener()`.

abstract class AnimatedLocationController implements ChangeNotifier {
  // Factory constructor redirects to underlying implementation's constructor.
  factory AnimatedLocationController() = AnimatedLocationControllerImpl._;

  /// Location may be null if the location permissions aren't granted or the location service is turned of.

  LatLng? get location;

  double get accuracy;

  /// Orientation may be null if the device doesn't provide the respective sensors.

  double? get orientation;


  /// Location may be null if the location permissions aren't granted or the location service is turned of.

  LatLng? get rawLocation;

  double get rawAccuracy;

  /// Orientation may be null if the device doesn't provide the respective sensors.

  double? get rawOrientation;


  /// The time interval in which new location data should be fetched.
  Duration get locationUpdateInterval;

  /// The time interval in which new sensor data should be fetched.
  Duration get orientationUpdateInterval;

  /// The minimal distance difference in meters of the new and the previous position that will be detected as a change.
  int get locationDifferenceThreshold;

  /// The minimal difference in radians of the new and the previous orientation that will be detected as a change.
  double get orientationDifferenceThreshold;


  /// The minimal difference in meters of the new and the previous accuracy that will be detected as a change.
  double get accuracyDifferenceThreshold;


  bool get isActive;

  void activate();

  void deactivate();

  /// Calls listener every time the raw location or orientation changes.
  void addRawListener(VoidCallback listener);

  /// Stops calling the listener every time the raw location or orientation changes.
  void removeRawListener(VoidCallback listener);
}

/// Used to hide internal setters and functions.

class AnimatedLocationControllerImpl extends ChangeNotifier implements AnimatedLocationController {
  StreamSubscription<Position>? _locationStreamSub;
  StreamSubscription<SensorEvent>? _orientationStreamSub;

  late final StreamSubscription<ServiceStatus> _serviceStatusStreamSub;

  AnimatedLocationControllerImpl._({
    Duration locationUpdateInterval = const Duration(milliseconds: 1000),
    Duration orientationUpdateInterval = const Duration(milliseconds: 200),
    int locationDifferenceThreshold = 1,
    double orientationDifferenceThreshold = 0.1,
    double accuracyDifferenceThreshold = 0.5,
  }) :
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

  @override
  bool get isActive => _locationStreamSub != null;

  @override
  void activate() {
    if (isActive) deactivate();
    _setupLocationStream();
    _setupRotationSensorStream();
    notifyListeners();
  }

  @override
  void deactivate() {
    _cleanupLocationStream();
    _cleanupRotationSensorStream();
    notifyListeners();
  }

  Duration _locationUpdateInterval;
  @override
  Duration get locationUpdateInterval => _locationUpdateInterval;
  set locationUpdateInterval(Duration value) {
    if (value != _locationUpdateInterval) {
      _locationUpdateInterval = value;
      _cleanupLocationStream();
      _setupLocationStream();
    }
  }

  Duration _orientationUpdateInterval;
  @override
  Duration get orientationUpdateInterval => _orientationUpdateInterval;
  set orientationUpdateInterval(Duration value) {
    if (value != _orientationUpdateInterval) {
      _orientationUpdateInterval = value;
      _cleanupRotationSensorStream();
      _setupRotationSensorStream();
    }
  }

  int _locationDifferenceThreshold;
  @override
  int get locationDifferenceThreshold => _locationDifferenceThreshold;
  set locationDifferenceThreshold(int value) {
    if (value != _locationDifferenceThreshold) {
      _locationDifferenceThreshold = value;
      _cleanupLocationStream();
      _setupLocationStream();
    }
  }

  double _orientationDifferenceThreshold;
  @override
  double get orientationDifferenceThreshold => _orientationDifferenceThreshold;
  set orientationDifferenceThreshold(double value) {
    if (value != _orientationDifferenceThreshold) {
      _orientationDifferenceThreshold = value;
      _cleanupRotationSensorStream();
      _setupRotationSensorStream();
    }
  }

  double _accuracyDifferenceThreshold;
  @override
  double get accuracyDifferenceThreshold => _accuracyDifferenceThreshold;
  set accuracyDifferenceThreshold(double value) {
    if (value != _accuracyDifferenceThreshold) {
      _accuracyDifferenceThreshold = value;
      _cleanupLocationStream();
      _setupLocationStream();
    }
  }

  // animated/interpolated location and sensors value

  LatLng? _location;
  @override
  LatLng? get location => _location;
  set location(LatLng? value) {
    if (value != _location) {
      _location = value;
      notifyListeners();
    }
  }

  double _accuracy = 0;
  @override
  double get accuracy => _accuracy;
  set accuracy(double value) {
    if (value != _accuracy) {
      _accuracy = value;
      notifyListeners();
    }
  }

  double? _orientation;
  @override
  double? get orientation => _orientation;
  set orientation(double? value) {
    if (value != _orientation) {
      _orientation = value;
      notifyListeners();
    }
  }

  // raw location and sensor values

  LatLng? _rawLocation;
  @override
  LatLng? get rawLocation => _rawLocation;

  double _rawAccuracy = 0;
  @override
  double get rawAccuracy => _rawAccuracy;

  double? _rawOrientation;
  @override
  double? get rawOrientation => _rawOrientation;

  // raw listener methods

  final _rawListeners = ObserverList<VoidCallback>();

  @override
  void addRawListener(VoidCallback listener) {
    _rawListeners.add(listener);
  }

  @override
  void removeRawListener(VoidCallback listener) {
    _rawListeners.remove(listener);
  }

  void _notifyRawListeners() {
    for (final listener in _rawListeners) {
      listener();
    }
  }

  // location methods

  void _setupLocationStream() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (locationServiceEnabled) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _locationStreamSub = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            intervalDuration: locationUpdateInterval,
            distanceFilter: locationDifferenceThreshold,
          )
        ).listen(_handlePositionEvent, onError: (_) => deactivate());
      }
    }
  }

  void _cleanupLocationStream() {
    _locationStreamSub?.cancel();
    _locationStreamSub = null;
  }

  void _handlePositionEvent(Position event) {
    _rawLocation = LatLng(event.latitude, event.longitude);

    final newAccuracy = event.accuracy;
    // check if difference threshold is reached
    if ((_rawAccuracy - newAccuracy).abs() > accuracyDifferenceThreshold) {
      _rawAccuracy = newAccuracy;
    }
    _notifyRawListeners();
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
      _notifyRawListeners();
    }
  }

  @override
  void dispose() {
    _serviceStatusStreamSub.cancel();
    _rawListeners.clear();
    deactivate();
    super.dispose();
  }
}
