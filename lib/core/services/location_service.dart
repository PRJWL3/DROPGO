// Location services utility wrapper class using geolocator and geocoding API mappings
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationServiceDisabledException implements Exception {
  final String message;
  const LocationServiceDisabledException([this.message = "Location services are disabled on the system."]);

  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException([this.message = "Location permission was denied by the user."]);

  @override
  String toString() => message;
}

class LocationPermissionPermanentlyDeniedException implements Exception {
  final String message;
  const LocationPermissionPermanentlyDeniedException([this.message = "Location permission permanently denied. Please enable in app settings."]);

  @override
  String toString() => message;
}

class LocationService {
  const LocationService();

  /// Requests location permissions.
  /// Throws meaningful exceptions if services are disabled or permissions are denied.
  Future<bool> requestPermission() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    // Check checkPermission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }

    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Fetches the current location coordinates of the user.
  Future<Position> getCurrentLocation() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw const LocationPermissionDeniedException("Location permission not granted.");
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  /// Exposes active coordinate changes as a stream.
  Stream<Position> getPositionStream() {
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Converts lat/lng coordinates into a readable address (Street, Area, City).
  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final street = place.street ?? '';
        final area = place.subLocality ?? place.locality ?? '';
        final city = place.subAdministrativeArea ?? place.administrativeArea ?? '';

        final List<String> parts = [];
        if (street.isNotEmpty) {
          parts.add(street);
        }
        if (area.isNotEmpty) {
          parts.add(area);
        }
        if (city.isNotEmpty) {
          parts.add(city);
        }
        
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
    return "Unknown location";
  }
}
