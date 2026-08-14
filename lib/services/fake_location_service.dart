// Fake location search and routing service
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/rider/models/ride_model.dart';

class FakeLocationService {
  FakeLocationService._();

  static const List<LocationPoint> suggestions = [
    LocationPoint(latitude: 12.9716, longitude: 77.5946, name: "Bengaluru City Center"),
    LocationPoint(latitude: 12.9279, longitude: 77.6271, name: "Koramangala 5th Block"),
    LocationPoint(latitude: 12.9562, longitude: 77.5678, name: "Vijayanagar Metro Station"),
    LocationPoint(latitude: 12.9783, longitude: 77.5724, name: "Majestic Bus Stand"),
    LocationPoint(latitude: 13.1986, longitude: 77.7066, name: "Kempegowda International Airport"),
    LocationPoint(latitude: 12.9304, longitude: 77.5830, name: "Jayanagar 4th Block"),
    LocationPoint(latitude: 12.9738, longitude: 77.6119, name: "MG Road Metro Station"),
  ];

  static double calculateDistance(LocationPoint start, LocationPoint end) {
    const double r = 6371.0; // Earth's radius in km
    final double dLat = _toRadians(end.latitude - start.latitude);
    final double dLon = _toRadians(end.longitude - start.longitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(start.latitude)) *
            math.cos(_toRadians(end.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) {
    return degree * (math.pi / 180.0);
  }

  static Map<String, double> estimateFareAndDuration(double distanceKm, String driverClass) {
    double baseRate;
    double perKmRate;
    double speedKmh = 35.0; // average city speed

    switch (driverClass) {
      case 'Bike Quick-Ride':
        baseRate = 20.0;
        perKmRate = 8.0;
        speedKmh = 45.0;
        break;
      case 'SUV Family-Ride':
        baseRate = 80.0;
        perKmRate = 22.0;
        speedKmh = 30.0;
        break;
      case 'Auto Eco-Ride':
      default:
        baseRate = 35.0;
        perKmRate = 12.0;
        speedKmh = 35.0;
        break;
    }

    final double price = baseRate + (distanceKm * perKmRate);
    final double durationMinutes = (distanceKm / speedKmh) * 60.0;

    return {
      'price': price,
      'duration': durationMinutes,
    };
  }
}

// Backward compatibility class mapping for unit tests
class LocationService {
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return FakeLocationService.calculateDistance(
      LocationPoint(latitude: lat1, longitude: lon1, name: "Start"),
      LocationPoint(latitude: lat2, longitude: lon2, name: "End"),
    );
  }

  double estimatePrice(LocationPoint start, LocationPoint end) {
    final distance = FakeLocationService.calculateDistance(start, end);
    return FakeLocationService.estimateFareAndDuration(distance, 'Auto Eco-Ride')['price']!;
  }

  List<LocationPoint> generateRoute(LocationPoint start, LocationPoint end, {int steps = 10}) {
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

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
