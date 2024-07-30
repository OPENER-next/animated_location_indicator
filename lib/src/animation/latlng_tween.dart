import 'package:flutter/animation.dart';
import 'package:latlong2/latlong.dart';

/// Interpolate latitude and longitude values.

class LatLngTween extends Tween<LatLng?> {
  static const piDoubled = pi * 2;

  LatLngTween({ LatLng? begin, LatLng? end }) : super(begin: begin, end: end);

  @override
  LatLng? lerp(double t) {
    if (end == null || begin == null) {
      return begin ?? end;
    }
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
