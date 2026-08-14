import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'directions_service.dart';

class DirectionsService {
  const DirectionsService();

  Future<bool> _waitForGoogleMaps() async {
    for (int i = 0; i < 50; i++) {
      if (js_util.hasProperty(js_util.globalThis, 'google')) {
        final google = js_util.getProperty(js_util.globalThis, 'google');
        if (google != null && js_util.hasProperty(google, 'maps')) {
          final maps = js_util.getProperty(google, 'maps');
          if (maps != null && js_util.hasProperty(maps, 'DirectionsService')) {
            return true;
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<RouteInfo?> getDirections(LatLng origin, LatLng destination) async {
    final hasLoaded = await _waitForGoogleMaps();
    if (!hasLoaded) {
      debugPrint("Google Maps Directions JS not loaded");
      return null;
    }

    final completer = Completer<RouteInfo?>();

    try {
      final google = js_util.getProperty(js_util.globalThis, 'google');
      final maps = js_util.getProperty(google, 'maps');
      final directionsConstructor = js_util.getProperty(maps, 'DirectionsService');
      final service = js_util.callConstructor(directionsConstructor, []);

      final latLngConstructor = js_util.getProperty(maps, 'LatLng');
      final originLatLng = js_util.callConstructor(latLngConstructor, [origin.latitude, origin.longitude]);
      final destLatLng = js_util.callConstructor(latLngConstructor, [destination.latitude, destination.longitude]);

      final request = js_util.jsify({
        'origin': originLatLng,
        'destination': destLatLng,
        'travelMode': 'DRIVING',
        'provideRouteAlternatives': false,
      });

      js_util.callMethod(service, 'route', [
        request,
        js.allowInterop((result, status) {
          try {
            final statusStr = status?.toString() ?? 'UNKNOWN';
            debugPrint("Directions status: $statusStr");

            if (statusStr != 'OK') {
              throw Exception("Directions status is not OK: $statusStr");
            }

            if (result == null) {
              throw Exception("Directions result is null");
            }

            final routes = js_util.getProperty(result, 'routes');
            if (routes == null) {
              throw Exception("routes is null");
            }

            final routesCount = routes != null ? (js_util.getProperty(routes, 'length') as int? ?? 0) : 0;
            debugPrint("Routes count: $routesCount");

            if (routesCount == 0) {
              throw Exception("routes count is 0");
            }

            final route = js_util.getProperty(routes, 0);
            if (route == null) {
              throw Exception("route at index 0 is null");
            }

            // Print route keys
            try {
              final objectConstructor = js_util.getProperty(js_util.globalThis, 'Object');
              final keys = js_util.callMethod(objectConstructor, 'keys', [route]);
              debugPrint("route keys: $keys");
            } catch (keyErr) {
              debugPrint("could not read route keys: $keyErr");
            }

            final legs = js_util.getProperty(route, 'legs');
            if (legs == null) {
              throw Exception("legs is null");
            }

            final leg = js_util.getProperty(legs, 0);
            if (leg == null) {
              throw Exception("leg at index 0 is null");
            }

            final distanceObj = js_util.getProperty(leg, 'distance');
            final durationObj = js_util.getProperty(leg, 'duration');

            final distanceText = distanceObj != null ? (js_util.getProperty(distanceObj, 'text')?.toString() ?? '') : '';
            final durationText = durationObj != null ? (js_util.getProperty(durationObj, 'text')?.toString() ?? '') : '';

            debugPrint("distance: $distanceText");
            debugPrint("duration: $durationText");

            final distanceKm = double.tryParse(distanceText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 12.4;
            final durationMin = double.tryParse(durationText.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 24.0;
            final double estimatedFare = 20.0 + (distanceKm * 8.0) + (durationMin * 1.0);

            // Read overview_path from google maps response
            final overviewPath = js_util.getProperty(route, 'overview_path');
            final pathLength = overviewPath != null ? (js_util.getProperty(overviewPath, 'length') as int? ?? 0) : 0;
            debugPrint("overview_path length: $pathLength");

            final List<LatLng> points = [];
            for (var i = 0; i < pathLength; i++) {
              final latLngObj = js_util.getProperty(overviewPath, i);
              if (latLngObj != null) {
                final lat = js_util.callMethod(latLngObj, 'lat', []) as num? ?? 0.0;
                final lng = js_util.callMethod(latLngObj, 'lng', []) as num? ?? 0.0;

                final latVal = lat.toDouble();
                final lngVal = lng.toDouble();

                // Validate coordinates
                if (latVal >= -90.0 && latVal <= 90.0 && lngVal >= -180.0 && lngVal <= 180.0) {
                  final newPoint = LatLng(latVal, lngVal);
                  // Remove duplicate consecutive points
                  if (points.isEmpty || points.last != newPoint) {
                    points.add(newPoint);
                  }
                }
              }
            }

            if (points.isNotEmpty) {
              debugPrint("First point: ${points.first}");
              debugPrint("Last point: ${points.last}");
            }
            debugPrint("final decoded point count: ${points.length}");

            completer.complete(RouteInfo(
              distanceKm: distanceKm,
              durationMin: durationMin,
              estimatedFare: estimatedFare,
              points: points,
            ));
          } catch (callbackErr) {
            debugPrint("Error inside Directions callback: $callbackErr");
            completer.complete(null);
          }
        })
      ]);
    } catch (e) {
      debugPrint("Web JS Directions error: $e");
      completer.complete(null);
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint("getDirections timeout");
        return null;
      },
    );
  }
}
