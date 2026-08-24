import 'package:google_maps_flutter/google_maps_flutter.dart';

class TaxiTownMapCamera {
  /// Calculate LatLngBounds enclosing a list of points
  static LatLngBounds getBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Center map camera on a single position with a specific zoom
  static Future<void> centerOnLocation(
    GoogleMapController controller,
    LatLng position, {
    double zoom = 16.0,
  }) async {
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: zoom,
        ),
      ),
    );
  }

  /// Fit map camera to enclose all specified points with padding
  static Future<void> fitPoints(
    GoogleMapController controller,
    List<LatLng> points, {
    double padding = 80.0,
  }) async {
    if (points.isEmpty) return;
    final bounds = getBounds(points);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  /// Fit map camera to enclose pickup and destination coordinates
  static Future<void> fitPickupAndDestination(
    GoogleMapController controller,
    LatLng pickup,
    LatLng destination, {
    double padding = 80.0,
  }) async {
    await fitPoints(controller, [pickup, destination], padding: padding);
  }
}
