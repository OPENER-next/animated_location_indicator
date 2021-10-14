import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';

import '/src/animated_location_options.dart';
import '/src/animated_location_layer.dart';

class AnimatedLocationPlugin implements MapPlugin {
  @override
  Widget createLayer(LayerOptions options, MapState mapState, Stream<Null> stream) {
    if (options is AnimatedLocationOptions) {
      return AnimatedLocationLayer(options, mapState, stream);
    }
    throw Exception('Unknown options type for AnimatedLocation plugin: $options');
  }

  @override
  bool supportsLayer(LayerOptions options) {
    return options is AnimatedLocationOptions;
  }
}