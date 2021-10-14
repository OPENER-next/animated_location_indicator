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
  final mapController = MapController();

  @override
  void initState() {
    super.initState();

    mapController.onReady.then((value) async {
      final position = await acquireUserLocation();
      if (position != null) {
        mapController.move(LatLng(position.latitude, position.longitude), 16);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: MyApp.title,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(MyApp.title),
        ),
        body: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            enableMultiFingerGestureRace: true,
          ),
          children: [
            TileLayerWidget(
              options: TileLayerOptions(
                overrideTilesWhenUrlChanges: true,
                urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(),
              ),
            ),
            AnimatedLocationLayerWidget(
              options: AnimatedLocationOptions(),
            )
          ],
        )
      )
    );
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