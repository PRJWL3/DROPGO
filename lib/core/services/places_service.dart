import 'places_service_mobile.dart' if (dart.library.html) 'places_service_web.dart' as impl;

class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

class PlaceDetails {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class PlacesService {
  final impl.PlacesService _impl = const impl.PlacesService();

  const PlacesService();

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    return await _impl.searchPlaces(query);
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    return await _impl.getPlaceDetails(placeId);
  }
}
