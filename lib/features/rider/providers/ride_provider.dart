// Ride booking notifier provider for flow controls and simulator
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ride_model.dart';
import '../models/saved_place_model.dart';
import '../../../services/fake_location_service.dart';
import '../../../services/fake_tracking_service.dart';

class RideBookingState {
  final RiderStatus status;
  final LocationPoint? pickup;
  final LocationPoint? destination;
  final Ride? activeRide;
  final String selectedDriverClass; // "Auto Eco-Ride", "Bike Quick-Ride", "SUV Family-Ride"
  final double price;
  final List<SavedPlace> savedPlaces;
  final List<Ride> pastRides;

  RideBookingState({
    this.status = RiderStatus.idle,
    this.pickup,
    this.destination,
    this.activeRide,
    this.selectedDriverClass = "Auto Eco-Ride",
    this.price = 0.0,
    this.savedPlaces = const [],
    this.pastRides = const [],
  });

  RideBookingState copyWith({
    RiderStatus? status,
    LocationPoint? Function()? pickup,
    LocationPoint? Function()? destination,
    Ride? Function()? activeRide,
    String? selectedDriverClass,
    double? price,
    List<SavedPlace>? savedPlaces,
    List<Ride>? pastRides,
  }) {
    return RideBookingState(
      status: status ?? this.status,
      pickup: pickup != null ? pickup() : this.pickup,
      destination: destination != null ? destination() : this.destination,
      activeRide: activeRide != null ? activeRide() : this.activeRide,
      selectedDriverClass: selectedDriverClass ?? this.selectedDriverClass,
      price: price ?? this.price,
      savedPlaces: savedPlaces ?? this.savedPlaces,
      pastRides: pastRides ?? this.pastRides,
    );
  }
}

class RideBookingNotifier extends StateNotifier<RideBookingState> {
  final Ref _ref;
  final SharedPreferences _prefs;
  Timer? _simulationTimer;
  List<LocationPoint> _simulatedRoutePoints = [];
  int _simulatedRouteIndex = 0;

  RideBookingNotifier(this._prefs, this._ref) : super(RideBookingState()) {
    _loadData();
  }

  void _loadData() {
    final savedPlacesJson = _prefs.getString('manaride_saved_places');
    List<SavedPlace> places = [];
    if (savedPlacesJson != null) {
      try {
        final List decoded = jsonDecode(savedPlacesJson);
        places = decoded.map((item) => SavedPlace.fromJson(item)).toList();
      } catch (_) {}
    } else {
      places = const [
        SavedPlace(
          id: "sp_home",
          label: "Home",
          address: "Ramapuram, Anantapur",
          latitude: 12.9716,
          longitude: 77.5946,
          iconName: "home",
        ),
        SavedPlace(
          id: "sp_work",
          label: "College",
          address: "Alliance University",
          latitude: 12.9562,
          longitude: 77.5678,
          iconName: "school",
        ),
      ];
      _prefs.setString('manaride_saved_places', jsonEncode(places.map((p) => p.toJson()).toList()));
    }

    final pastRidesJson = _prefs.getString('manaride_past_rides');
    List<Ride> history = [];
    if (pastRidesJson != null) {
      try {
        final List decoded = jsonDecode(pastRidesJson);
        history = decoded.map((item) => Ride.fromJson(item)).toList();
      } catch (_) {}
    } else {
      history = [
        Ride(
          id: "ride_past_1",
          pickup: const LocationPoint(latitude: 12.9716, longitude: 77.5946, name: "Town Center Market"),
          destination: const LocationPoint(latitude: 12.9634, longitude: 77.5855, name: "Rural Health Clinic"),
          price: 45.0,
          status: RiderStatus.rated,
          otp: "5555",
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          driver: const Driver(
            id: "d_past_1",
            name: "Ramesh Kumar",
            phone: "+12345",
            photoUrl: "",
            vehicleModel: "Electric Auto-Rickshaw",
            vehiclePlate: "KA-05-AA-1111",
          ),
        ),
      ];
      _prefs.setString('manaride_past_rides', jsonEncode(history.map((r) => r.toJson()).toList()));
    }

    state = state.copyWith(savedPlaces: places, pastRides: history);
  }

  void addSavedPlace(SavedPlace place) {
    final updated = [...state.savedPlaces, place];
    _prefs.setString('manaride_saved_places', jsonEncode(updated.map((p) => p.toJson()).toList()));
    state = state.copyWith(savedPlaces: updated);
  }

  void startSelectingRoute() {
    state = state.copyWith(status: RiderStatus.selectingRoute);
  }

  void selectPickup(LocationPoint point) {
    state = state.copyWith(
      pickup: () => point,
      status: state.destination != null ? RiderStatus.fareEstimated : RiderStatus.selectingRoute,
    );
    _calculatePrice();
  }

  void selectDestination(LocationPoint point) {
    state = state.copyWith(
      destination: () => point,
      status: state.pickup != null ? RiderStatus.fareEstimated : RiderStatus.selectingRoute,
    );
    _calculatePrice();
  }

  void swapLocations() {
    final p = state.pickup;
    final d = state.destination;
    state = state.copyWith(
      pickup: () => d,
      destination: () => p,
    );
    _calculatePrice();
  }

  void selectDriverClass(String driverClass) {
    state = state.copyWith(selectedDriverClass: driverClass);
    _calculatePrice();
  }

  void _calculatePrice() {
    if (state.pickup == null || state.destination == null) return;
    final distance = FakeLocationService.calculateDistance(state.pickup!, state.destination!);
    final fareDetails = FakeLocationService.estimateFareAndDuration(distance, state.selectedDriverClass);
    final double price = double.parse(fareDetails['price']!.toStringAsFixed(0));
    state = state.copyWith(price: price);
  }

  void confirmFare() {
    state = state.copyWith(status: RiderStatus.searching);
    _simulateDriverMatch();
  }

  void _simulateDriverMatch() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer(const Duration(seconds: 3), () {
      final mockOtp = (1000 + (8999 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000)).toInt().toString();

      final activeRide = Ride(
        id: "ride_${DateTime.now().millisecondsSinceEpoch}",
        pickup: state.pickup!,
        destination: state.destination!,
        price: state.price,
        status: RiderStatus.accepted,
        otp: mockOtp,
        timestamp: DateTime.now(),
        driver: Driver(
          id: "d_${DateTime.now().millisecondsSinceEpoch}",
          name: "Ramesh Kumar",
          phone: "+91 98765 43210",
          photoUrl: "",
          vehicleModel: state.selectedDriverClass == "Bike Quick-Ride"
              ? "Bajaj CT100 (Bike)"
              : (state.selectedDriverClass == "SUV Family-Ride" ? "Mahindra Bolero (SUV)" : "Mahindra Treo (Electric Auto)"),
          vehiclePlate: "KA-05-AA-5678",
          rating: 4.8,
          currentLat: state.pickup!.latitude + 0.012,
          currentLng: state.pickup!.longitude + 0.012,
        ),
      );

      state = state.copyWith(
        status: RiderStatus.accepted,
        activeRide: () => activeRide,
      );

      _simulateDriverArriving();
    });
  }

  void _simulateDriverArriving() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer(const Duration(seconds: 4), () {
      if (state.activeRide == null) return;

      final active = state.activeRide!.copyWith(
        status: RiderStatus.arriving,
        driver: state.activeRide!.driver?.copyWith(
          currentLat: state.pickup!.latitude + 0.001,
          currentLng: state.pickup!.longitude + 0.001,
        ),
      );

      state = state.copyWith(
        status: RiderStatus.arriving,
        activeRide: () => active,
      );
    });
  }

  bool verifyOtpPin(String pin) {
    if (state.activeRide != null && state.activeRide!.otp == pin) {
      final active = state.activeRide!.copyWith(status: RiderStatus.inProgress);
      state = state.copyWith(
        status: RiderStatus.inProgress,
        activeRide: () => active,
      );

      _simulatedRoutePoints = FakeTrackingService.interpolatePoints(
        LocationPoint(
          latitude: active.driver!.currentLat,
          longitude: active.driver!.currentLng,
          name: "Driver current",
        ),
        active.destination,
        steps: 10,
      );
      _simulatedRouteIndex = 0;

      _simulateMovementToDestination();
      return true;
    }
    return false;
  }

  void _simulateMovementToDestination() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state.activeRide == null) {
        timer.cancel();
        return;
      }

      if (_simulatedRouteIndex < _simulatedRoutePoints.length - 1) {
        _simulatedRouteIndex++;
        final nextCoord = _simulatedRoutePoints[_simulatedRouteIndex];

        final updatedRide = state.activeRide!.copyWith(
          driver: state.activeRide!.driver?.copyWith(
            currentLat: nextCoord.latitude,
            currentLng: nextCoord.longitude,
          ),
        );

        state = state.copyWith(activeRide: () => updatedRide);
      } else {
        timer.cancel();
        _completeRide();
      }
    });
  }

  void _completeRide() {
    if (state.activeRide == null) return;

    final completedRide = state.activeRide!.copyWith(status: RiderStatus.completed);
    final updatedHistory = [completedRide, ...state.pastRides];

    _prefs.setString('manaride_past_rides', jsonEncode(updatedHistory.map((r) => r.toJson()).toList()));

    state = state.copyWith(
      status: RiderStatus.completed,
      activeRide: () => completedRide,
      pastRides: updatedHistory,
    );
  }

  void rateDriver(double rating) {
    if (state.activeRide == null) return;

    final ratedRide = state.activeRide!.copyWith(status: RiderStatus.rated);
    final updatedHistory = state.pastRides.map((r) => r.id == ratedRide.id ? ratedRide : r).toList();

    _prefs.setString('manaride_past_rides', jsonEncode(updatedHistory.map((r) => r.toJson()).toList()));

    state = state.copyWith(
      status: RiderStatus.idle,
      activeRide: () => null,
      pickup: () => null,
      destination: () => null,
      pastRides: updatedHistory,
    );
  }

  void cancelRideSearch() {
    _simulationTimer?.cancel();
    state = state.copyWith(
      status: RiderStatus.idle,
      activeRide: () => null,
      pickup: () => null,
      destination: () => null,
    );
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final rideBookingNotifierProvider = StateNotifierProvider<RideBookingNotifier, RideBookingState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RideBookingNotifier(prefs, ref);
});
