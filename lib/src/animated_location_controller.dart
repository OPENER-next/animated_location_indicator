import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Can be used to retrieve the underlying values (real and interpolated) that drive the indicators.

abstract class AnimatedLocationController implements ChangeNotifier {
  // Factory constructor redirects to underlying implementation's constructor.
  factory AnimatedLocationController() = AnimatedLocationControllerImpl._;

  /// Location may be null if the location permissions aren't granted or the location service is turned of.

  LatLng? get location;

  double get accuracy;

  /// Orientation may be null if the device doesn't provide the respective sensors.

  double? get orientation;
}

/// Used to hide internal setters and functions.

class AnimatedLocationControllerImpl extends ChangeNotifier implements AnimatedLocationController {
  AnimatedLocationControllerImpl._();

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
}
