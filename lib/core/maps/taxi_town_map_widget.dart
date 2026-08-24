import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/map_style.dart';

/// Shared, standardized GoogleMap wrapper widget that enforces TaxiTown styling
class TaxiTownMap extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final MapCreatedCallback? onMapCreated;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool compassEnabled;
  final bool mapToolbarEnabled;
  final EdgeInsets padding;

  const TaxiTownMap({
    super.key,
    required this.initialCameraPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.compassEnabled = false,
    this.mapToolbarEnabled = false,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GoogleMap(
        initialCameraPosition: initialCameraPosition,
        myLocationEnabled: myLocationEnabled,
        myLocationButtonEnabled: myLocationButtonEnabled,
        zoomControlsEnabled: zoomControlsEnabled,
        compassEnabled: compassEnabled,
        mapToolbarEnabled: mapToolbarEnabled,
        markers: markers,
        polylines: polylines,
        padding: padding,
        onMapCreated: (controller) {
          controller.setMapStyle(premiumMapStyle);
          if (onMapCreated != null) {
            onMapCreated!(controller);
          }
        },
      ),
    );
  }
}
