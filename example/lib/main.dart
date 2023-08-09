import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:animated_location_indicator/animated_location_indicator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  static const title = 'Animated Location Indicator Plugin Demo';

  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: MyApp.title,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(MyApp.title),
        ),
        body: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            interactionOptions: const InteractionOptions(
              enableMultiFingerGestureRace: true,
            ),
            onMapReady: () async {
              final position = await acquireUserLocation();
              if (position != null) {
                // IMPORTANT: rebuild location layer when permissions are granted
                setState(() {
                  _mapController.move(LatLng(position.latitude, position.longitude), 16);
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              tileProvider: NetworkTileProvider(),
            ),
            const AnimatedLocationLayer(
              // cameraTrackingMode: CameraTrackingMode.locationAndOrientation,
            ),
          ],
        )
      )
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}


Future<Position?> acquireUserLocation() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return null;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return null;
  }

  try {
    return await Geolocator.getCurrentPosition();
  }
  on LocationServiceDisabledException {
    return null;
  }
}
