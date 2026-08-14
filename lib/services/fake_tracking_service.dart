// Fake simulation tracking service for route interpolation
import '../features/rider/models/ride_model.dart';

class FakeTrackingService {
  FakeTrackingService._();

  /// Interpolates a list of coordinates between start and end to simulate movement
  static List<LocationPoint> interpolatePoints(
    LocationPoint start,
    LocationPoint end, {
    int steps = 15,
  }) {
    final List<LocationPoint> points = [];
    for (int i = 0; i <= steps; i++) {
      final double fraction = i / steps;
      final double lat = start.latitude + (end.latitude - start.latitude) * fraction;
      final double lng = start.longitude + (end.longitude - start.longitude) * fraction;
      points.add(
        LocationPoint(
          latitude: lat,
          longitude: lng,
          name: "Way point $i",
        ),
      );
    }
    return points;
  }
}
