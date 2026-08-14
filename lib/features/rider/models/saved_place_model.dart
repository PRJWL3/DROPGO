// Saved place domain model
import 'package:flutter/foundation.dart';

@immutable
class SavedPlace {
  final String id;
  final String label; // "Home", "Work", etc.
  final String address;
  final double latitude;
  final double longitude;
  final String iconName; // e.g. "home", "work", "location_on"

  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.iconName = "location_on",
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'iconName': iconName,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        label: json['label'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        iconName: json['iconName'] as String? ?? "location_on",
      );
}
