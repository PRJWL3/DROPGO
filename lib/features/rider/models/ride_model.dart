// Ride domain models (Location, Driver, and Booking State)
import 'package:flutter/foundation.dart';

enum RiderStatus {
  idle,
  selectingRoute,
  fareEstimated,
  searching,
  accepted,
  arriving,
  inProgress,
  completed,
  rated,
  noDriversAvailable;

  String get displayName {
    switch (this) {
      case RiderStatus.idle:
        return 'Idle';
      case RiderStatus.selectingRoute:
        return 'Selecting Route';
      case RiderStatus.fareEstimated:
        return 'Fare Estimated';
      case RiderStatus.searching:
        return 'Searching Driver';
      case RiderStatus.accepted:
        return 'Ride Accepted';
      case RiderStatus.arriving:
        return 'Driver Arriving';
      case RiderStatus.inProgress:
        return 'Trip in Progress';
      case RiderStatus.completed:
        return 'Trip Completed';
      case RiderStatus.rated:
        return 'Rated';
      case RiderStatus.noDriversAvailable:
        return 'No Drivers Available';
    }
  }
}

@immutable
class LocationPoint {
  final double latitude;
  final double longitude;
  final String name;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
      };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

@immutable
class Driver {
  final String id;
  final String name;
  final String phone;
  final String photoUrl;
  final String vehicleModel;
  final String vehiclePlate;
  final double rating;
  final double currentLat;
  final double currentLng;

  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.photoUrl,
    required this.vehicleModel,
    required this.vehiclePlate,
    this.rating = 4.8,
    this.currentLat = 0.0,
    this.currentLng = 0.0,
  });

  Driver copyWith({
    String? id,
    String? name,
    String? phone,
    String? photoUrl,
    String? vehicleModel,
    String? vehiclePlate,
    double? rating,
    double? currentLat,
    double? currentLng,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      rating: rating ?? this.rating,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'photoUrl': photoUrl,
        'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate,
        'rating': rating,
        'currentLat': currentLat,
        'currentLng': currentLng,
      };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        photoUrl: json['photoUrl'] as String? ?? "",
        vehicleModel: json['vehicleModel'] as String,
        vehiclePlate: json['vehiclePlate'] as String,
        rating: (json['rating'] as num).toDouble(),
        currentLat: (json['currentLat'] as num).toDouble(),
        currentLng: (json['currentLng'] as num).toDouble(),
      );
}

@immutable
class Ride {
  final String id;
  final LocationPoint pickup;
  final LocationPoint destination;
  final double price;
  final RiderStatus status;
  final String otp;
  final Driver? driver;
  final DateTime timestamp;
  final bool sosTriggered;

  const Ride({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.price,
    required this.status,
    required this.otp,
    this.driver,
    required this.timestamp,
    this.sosTriggered = false,
  });

  Ride copyWith({
    String? id,
    LocationPoint? pickup,
    LocationPoint? destination,
    double? price,
    RiderStatus? status,
    String? otp,
    Driver? driver,
    DateTime? timestamp,
    bool? sosTriggered,
  }) {
    return Ride(
      id: id ?? this.id,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      price: price ?? this.price,
      status: status ?? this.status,
      otp: otp ?? this.otp,
      driver: driver ?? this.driver,
      timestamp: timestamp ?? this.timestamp,
      sosTriggered: sosTriggered ?? this.sosTriggered,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'price': price,
        'status': status.name,
        'otp': otp,
        'driver': driver?.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'sosTriggered': sosTriggered,
      };

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        pickup: LocationPoint.fromJson(json['pickup'] as Map<String, dynamic>),
        destination: LocationPoint.fromJson(json['destination'] as Map<String, dynamic>),
        price: (json['price'] as num).toDouble(),
        status: RiderStatus.values.byName(json['status'] as String),
        otp: json['otp'] as String,
        driver: json['driver'] != null ? Driver.fromJson(json['driver'] as Map<String, dynamic>) : null,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sosTriggered: json['sosTriggered'] as bool? ?? false,
      );
}
