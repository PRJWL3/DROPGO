import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'places_service.dart';

bool isGoogleMapsLoaded() {
  if (!kIsWeb) return false;
  final google = js_util.getProperty(js_util.globalThis, 'google');
  return google != null;
}

class PlacesService {
  const PlacesService();

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (!isGoogleMapsLoaded()) {
      print('Google Maps JS is NOT loaded');
      return [];
    }
    print('Google Maps JS is loaded');
    
    final google = js_util.getProperty(js_util.globalThis, 'google');
    final maps = js_util.getProperty(google, 'maps');
    final places = maps != null ? js_util.getProperty(maps, 'places') : null;
    
    if (places == null) {
      print('Places library is NOT available');
      return [];
    }
    print('Places library available');

    final completer = Completer<List<PlaceSuggestion>>();
    
    try {
      final autocompleteConstructor = js_util.getProperty(places, 'AutocompleteService');
      final service = js_util.callConstructor(autocompleteConstructor, []);
      
      final request = js_util.jsify({
        'input': query,
        'types': ['establishment', 'geocode'],
        'componentRestrictions': {'country': 'in'},
      });
      
      js_util.callMethod(service, 'getPlacePredictions', [
        request,
        js.allowInterop((predictions, status) {
          debugPrint("Web JS Autocomplete status: $status");
          if (status.toString() == 'OK' && predictions != null) {
            final list = <PlaceSuggestion>[];
            final length = js_util.getProperty(predictions, 'length') as int;
            for (var i = 0; i < length; i++) {
              final prediction = js_util.getProperty(predictions, i);
              final placeId = js_util.getProperty(prediction, 'place_id') as String;
              
              final structured = js_util.getProperty(prediction, 'structured_formatting');
              final mainText = js_util.getProperty(structured, 'main_text') as String;
              final secondaryText = js_util.getProperty(structured, 'secondary_text') as String? ?? '';
              
              list.add(PlaceSuggestion(
                placeId: placeId,
                mainText: mainText,
                secondaryText: secondaryText,
              ));
            }
            completer.complete(list);
          } else {
            completer.complete([]);
          }
        })
      ]);
    } catch (e) {
      debugPrint("Web places AutocompleteService error: $e");
      completer.complete([]);
    }
    
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint("searchPlaces timeout");
        return [];
      },
    );
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    if (!isGoogleMapsLoaded()) {
      print('Google Maps JS is NOT loaded');
      return null;
    }
    
    final google = js_util.getProperty(js_util.globalThis, 'google');
    final maps = js_util.getProperty(google, 'maps');
    
    if (maps == null) return null;

    final completer = Completer<PlaceDetails?>();
    
    try {
      final geocoderConstructor = js_util.getProperty(maps, 'Geocoder');
      final geocoder = js_util.callConstructor(geocoderConstructor, []);
      
      final request = js_util.jsify({
        'placeId': placeId,
      });
      
      js_util.callMethod(geocoder, 'geocode', [
        request,
        js.allowInterop((results, status) {
          if (status.toString() == 'OK' && results != null) {
            final length = js_util.getProperty(results, 'length') as int;
            if (length > 0) {
              final firstResult = js_util.getProperty(results, 0);
              final address = js_util.getProperty(firstResult, 'formatted_address') as String? ?? '';
              final name = address.split(',').first;
              
              final geometry = js_util.getProperty(firstResult, 'geometry');
              final location = js_util.getProperty(geometry, 'location');
              final lat = js_util.callMethod(location, 'lat', []) as num;
              final lng = js_util.callMethod(location, 'lng', []) as num;
              
              completer.complete(PlaceDetails(
                name: name,
                address: address,
                latitude: lat.toDouble(),
                longitude: lng.toDouble(),
              ));
              return;
            }
          }
          completer.complete(null);
        })
      ]);
    } catch (e) {
      debugPrint("Web geocode error: $e");
      completer.complete(null);
    }
    
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        debugPrint("getPlaceDetails timeout");
        return null;
      },
    );
  }
}
