# Animated Location Indicator

A simple yet customizable plugin for [Flutter Map](https://github.com/fleaflet/flutter_map) to display the current user location, accuracy and orientation along with automatically animating changes of these properties.

https://user-images.githubusercontent.com/13716661/137280525-d6320c43-e82a-4431-b293-640527ef9df0.mp4

## Features

- Location, accuracy and orientation indicator can be replaced by custom widgets
- Customizable default indicators
- Define custom animation curves and durations

## Getting started

This plugin requires the location permission. Since the plugin uses [geolocator](https://pub.dev/packages/geolocator) you can find more information there.

**Note:**  If the location permission isn't granted on widget build the location indicator will be hidden/disabled. Once the permission is granted you have to call `animatedLocationController.activate()` to activate it.

### Android

In order to use this plugin on Android, you have to add the following permission in the `AndroidManifest.xml` file:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Make sure that the `compileSdkVersion` version in `android/app/build.gradle` is set to `compileSdkVersion 31` or higher.

### iOS

In order to use this plugin on iOS, you have to add the following permission in the `Info.plist` file:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location when open.</string>
```

## Usage

Add `animated_location_indicator` to your pubspec:

```yml
dependencies:
  animated_location_indicator:
    git:
      url: https://github.com/OPENER-next/animated_location_indicator.git
```

Import the package.

```dart
import 'package:animated_location_indicator/animated_location_indicator.dart';
```

### Sample code

Add the the `AnimatedLocationLayerWidget` to the `children` of the `FlutterMap` widget.

```dart
FlutterMap(
  children: [
    TileLayerWidget(
      options: TileLayerOptions(
        urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
        tileProvider: NetworkTileProvider(),
      ),
    ),
    AnimatedLocationLayerWidget(
      options: AnimatedLocationOptions(
        // adjust appearance and behavior here
      ),
    )
  ],
)
```

Adjust the appearance of the default indicators.

```dart
AnimatedLocationLayerWidget(
  options: AnimatedLocationOptions(
    accuracyIndicator: const AccuracyIndicator(
      color: Colors.red,
      strokeColor: Colors.black,
      strokeWidth: 4,
    ),
    orientationIndicator: const OrientationIndicator(
      color: Colors.red,
      sectorSize: 2,
    ),
    locationIndicator: const LocationIndicator(
      color: Colors.red,
      strokeColor: Colors.black,
      strokeWidth: 4,
    )
  ),
)
```

Use custom indicator widgets.

```dart
AnimatedLocationLayerWidget(
  options: AnimatedLocationOptions(
    accuracyIndicator: MyCustomWidget(),
    orientationIndicator: MyCustomWidget(),
    locationIndicator: MyCustomWidget()
  ),
)
```

For a complete working example app visit the `/example` folder.