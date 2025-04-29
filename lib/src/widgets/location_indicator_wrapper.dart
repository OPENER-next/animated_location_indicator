import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide LatLngTween;
import 'package:latlong2/latlong.dart';

/// The rotation/orientation will implicitly animate whenever it changes.

class LocationIndicatorWrapper extends StatelessWidget {
  /// The value is expected to be in radians.

  final Animation<LatLng?> position;

  /// Any widgets that should be stacked on top of each other in the center.

  final List<Widget> children;

  const LocationIndicatorWrapper({
    required this.children,
    required this.position,
    super.key,
  });

  @override
  Widget build(context) {
    return MobileLayerTransformer(
      child: Flow(
        delegate: _FlowPositionDelegate(
          position: position,
          mapCamera: MapCamera.of(context),
        ),
        children: children,
      ),
    );
  }
}

/// Flow-Delegate to position the indicators.

class _FlowPositionDelegate extends FlowDelegate {

  final Animation<LatLng?> position;

  final MapCamera mapCamera;

  _FlowPositionDelegate({
    required this.position,
    required this.mapCamera,
  }) : super(repaint: position);


  @override
  bool shouldRepaint(_FlowPositionDelegate oldDelegate) {
    return position != oldDelegate.position ||
           mapCamera != oldDelegate.mapCamera;
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    if (position.value == null) return;

    final absPixelPosition = mapCamera.projectAtZoom(position.value!);
    final relPixelPosition = absPixelPosition - mapCamera.pixelOrigin;
    for (var i = 0; i < context.childCount; i++) {
      final childSize = context.getChildSize(i)!;
      final bounds = Rect.fromCenter(
        center: absPixelPosition,
        width: childSize.width,
        height: childSize.height,
      );
      // only render visible widgets
      if (mapCamera.pixelBounds.overlaps(bounds)) {
        context.paintChild(i,
          transform: Matrix4.translationValues(
            // center all widgets
            relPixelPosition.dx - childSize.width/2,
            relPixelPosition.dy - childSize.height/2,
            0,
          ),
        );
      }
    }
  }

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    // set constraints to infinity in order to allow the children (like the accuracy circle)
    // to size themselves bigger than the constraints passed from the outside (usually the screen size)
    return const BoxConstraints(
      maxHeight: double.infinity,
      maxWidth: double.infinity,
    );
  }
}
