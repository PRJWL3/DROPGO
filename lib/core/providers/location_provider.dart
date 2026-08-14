// Riverpod providers exposing system geolocator coordinates streams
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/directions_service.dart';
import '../services/places_service.dart';

// Provider exposing the location service dependency instance
final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

// FutureProvider exposing the single snapshot of current user position coordinates
final currentLocationProvider = FutureProvider<Position>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return await service.getCurrentLocation();
});

// StreamProvider exposing continuous updates of the user coordinates
final liveLocationProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.getPositionStream();
});

// FutureProvider exposing geocoded address for current user coordinates
final currentAddressProvider = FutureProvider<String>((ref) async {
  final position = await ref.watch(currentLocationProvider.future);
  final service = ref.watch(locationServiceProvider);
  return await service.getAddressFromLatLng(position.latitude, position.longitude);
});

// Provider exposing directions service dependency
final directionsServiceProvider = Provider<DirectionsService>((ref) {
  return const DirectionsService();
});

// FutureProvider Family to retrieve RouteInfo between two coordinates points
final routeInfoProvider = FutureProvider.family<RouteInfo?, ({LatLng origin, LatLng destination})>((ref, arg) async {
  final service = ref.read(directionsServiceProvider);
  return await service.getDirections(arg.origin, arg.destination);
});

// Provider exposing places service dependency
final placesServiceProvider = Provider<PlacesService>((ref) {
  return const PlacesService();
});
