import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'places_service.dart';

class PlacesService {
  final String _apiKey = "AIzaSyD_kJqdIJUqGFIzQ3RZ90f2TZFhNYzQ0Vc";

  const PlacesService();

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.length < 2) return [];
    try {
      final url = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
          "?input=${Uri.encodeComponent(query)}"
          "&components=country:in"
          "&types=establishment|geocode"
          "&key=$_apiKey";
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((p) {
            final formatting = p['structured_formatting'] ?? {};
            return PlaceSuggestion(
              placeId: p['place_id'] as String,
              mainText: (formatting['main_text'] ?? p['description'] ?? '') as String,
              secondaryText: (formatting['secondary_text'] ?? '') as String,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Places search mobile error: $e");
    }
    return [];
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = "https://maps.googleapis.com/maps/api/place/details/json"
          "?place_id=$placeId"
          "&key=$_apiKey";
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final name = result['name'] as String;
          final address = result['formatted_address'] as String;
          final geometry = result['geometry']['location'];
          final lat = (geometry['lat'] as num).toDouble();
          final lng = (geometry['lng'] as num).toDouble();
          
          return PlaceDetails(
            name: name,
            address: address,
            latitude: lat,
            longitude: lng,
          );
        }
      }
    } catch (e) {
      debugPrint("Place details mobile API Error: $e");
    }
    return null;
  }
}
