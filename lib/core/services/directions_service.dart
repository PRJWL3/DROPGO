import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'directions_service_mobile.dart' if (dart.library.html) 'directions_service_web.dart' as impl;

class RouteInfo {
  final double distanceKm;
  final double durationMin;
  final double estimatedFare;
  final List<LatLng> points;

  RouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.estimatedFare,
    required this.points,
  });
}

class DirectionsService {
  final impl.DirectionsService _impl = const impl.DirectionsService();

  const DirectionsService();

  Future<RouteInfo?> getDirections(LatLng origin, LatLng destination) async {
    return await _impl.getDirections(origin, destination);
  }
}
