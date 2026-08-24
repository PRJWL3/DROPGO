import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds a high-quality two-layer route polyline (white outline under colored fill)
Set<Polyline> buildRoutePolylines(List<LatLng> points, Color primaryColor) {
  if (points.isEmpty) return const {};

  return {
    Polyline(
      polylineId: const PolylineId("route_outline"),
      points: points,
      color: Colors.white,
      width: 10,
      jointType: JointType.round,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
    ),
    Polyline(
      polylineId: const PolylineId("route_fill"),
      points: points,
      color: primaryColor,
      width: 6,
      jointType: JointType.round,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
    ),
  };
}
