// Ride booking notifier provider for flow controls and simulator
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ride_model.dart';
import '../models/saved_place_model.dart';
import '../../../services/fake_location_service.dart';
import '../../../services/fake_tracking_service.dart';
import '../../../core/services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideBookingState {
  final RiderStatus status;
  final LocationPoint? pickup;
  final LocationPoint? destination;
  final Ride? activeRide;
  final String selectedDriverClass; // "Auto Eco-Ride", "Bike Quick-Ride", "SUV Family-Ride", "Bike"
  final double price;
  final List<SavedPlace> savedPlaces;
  final List<Ride> pastRides;

  RideBookingState({
    this.status = RiderStatus.idle,
    this.pickup,
    this.destination,
    this.activeRide,
    this.selectedDriverClass = "Bike",
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
  StreamSubscription? _rideSubscription;
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

  void tryAgain() {
    state = state.copyWith(status: RiderStatus.fareEstimated);
  }

  void confirmFare() async {
    if (state.status == RiderStatus.searching) return;

    final pickup = state.pickup;
    final destination = state.destination;
    final vehicleType = state.selectedDriverClass;
    final estimatedFare = state.price;

    // 1. BUTTON TRIGGER
    debugPrint("========== RIDE REQUEST START ==========");
    debugPrint("Find Drivers button pressed");

    // 2. VALIDATE RIDER DATA
    debugPrint("Pickup: ${pickup?.name}");
    debugPrint("Pickup coordinates: ${pickup?.latitude}, ${pickup?.longitude}");
    debugPrint("Destination: ${destination?.name}");
    debugPrint("Destination coordinates: ${destination?.latitude}, ${destination?.longitude}");
    debugPrint("Vehicle type: $vehicleType");
    debugPrint("Estimated fare: $estimatedFare");

    if (pickup == null ||
        destination == null ||
        pickup.name.isEmpty ||
        destination.name.isEmpty ||
        vehicleType.isEmpty ||
        estimatedFare <= 0) {
      debugPrint("RIDE REQUEST ABORTED: Missing required data");
      if (pickup == null) {
        debugPrint("- pickup is null");
      } else if (pickup.name.isEmpty) {
        debugPrint("- pickup address is empty");
      }
      if (destination == null) {
        debugPrint("- destination is null");
      } else if (destination.name.isEmpty) {
        debugPrint("- destination address is empty");
      }
      if (vehicleType.isEmpty) {
        debugPrint("- vehicleType is empty");
      }
      if (estimatedFare <= 0) {
        debugPrint("- estimatedFare is non-positive ($estimatedFare)");
      }
      
      _ref.read(rideErrorProvider.notifier).state = "RIDE REQUEST ABORTED: Missing required data";
      return;
    }

    state = state.copyWith(status: RiderStatus.searching);

    // 3. GENERATE RIDE ID
    final rideId = "ride_${DateTime.now().millisecondsSinceEpoch}";
    debugPrint("Creating ride request...");
    debugPrint("Ride ID: $rideId");

    // 4. FIREBASE STATUS
    final fbMode = FirebaseService.isFirebaseAvailable ? "FIREBASE" : "LOCAL SIMULATION";
    debugPrint("Firebase mode: $fbMode");
    debugPrint("Firebase initialized: ${FirebaseService.isFirebaseAvailable ? "YES" : "NO"}");

    final distance = FakeLocationService.calculateDistance(pickup, destination);
    final duration = distance * 2.0;
    final user = _ref.read(authProvider);
    final riderId = user.uid ?? "user_1234";
    final riderName = user.name ?? "Alex Rider";

    // Cancel old stream subscription
    _rideSubscription?.cancel();

    // 5. FIRESTORE WRITE & 7. FIRESTORE ERRORS
    try {
      debugPrint("Writing ride to Firestore...");
      debugPrint("Firestore path: /rides/$rideId");
      
      // Create the ride request document inside Cloud Firestore / Local Simulation
      await FirebaseService.createRideRequest(
        rideId: rideId,
        riderId: riderId,
        riderName: riderName,
        pickupAddress: pickup.name,
        pickupLat: pickup.latitude,
        pickupLng: pickup.longitude,
        destinationAddress: destination.name,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
        distanceKm: distance,
        durationMinutes: duration,
        estimatedFare: state.price,
        paymentMethod: 'Cash',
      );
      
      debugPrint("========== RIDE REQUEST CREATED ==========");
      debugPrint("Ride successfully written to Firestore");
      debugPrint("Ride ID: $rideId");
      debugPrint("Status: searching");
    } catch (e) {
      debugPrint("========== RIDE REQUEST FAILED ==========");
      debugPrint("Firestore error:");
      debugPrint("$e");
      if (e is FirebaseException) {
        debugPrint("Error Code: ${e.code}");
      }
      _ref.read(rideErrorProvider.notifier).state = "Failed to query drivers.";
      state = state.copyWith(status: RiderStatus.noDriversAvailable);
      return;
    }

    // 6. VERIFY THE WRITE
    debugPrint("Verifying ride document...");
    try {
      final verifiedRide = await FirebaseService.getRide(rideId);
      final exists = verifiedRide != null;
      debugPrint("Document exists: $exists");
      if (exists) {
        debugPrint("Ride ID: ${verifiedRide['rideId']}");
        debugPrint("Status: ${verifiedRide['status']}");
        debugPrint("Vehicle type: ${verifiedRide['vehicleType']}");
        debugPrint("Pickup: ${verifiedRide['pickupAddress']}");
        debugPrint("Destination: ${verifiedRide['destinationAddress']}");
        debugPrint("Expires at: ${verifiedRide['expiresAt']}");
      } else {
        debugPrint("CRITICAL: Ride write appeared successful but document cannot be read back");
      }
    } catch (e) {
      debugPrint("Verification readback failed: $e");
    }

    // Step 7: Check Local Simulation vs Firebase Mode
    final String laptopProjectId = FirebaseService.isFirebaseAvailable
        ? Firebase.app().options.projectId
        : "LOCAL_SIMULATION";

    if (FirebaseService.isFirebaseAvailable) {
      debugPrint("FIREBASE MODE ACTIVE");
    } else {
      debugPrint("LOCAL SIMULATION MODE ACTIVE");
    }

    if (FirebaseService.isFirebaseAvailable) {
      // STEP 1 — READ ALL DRIVER DOCUMENTS FROM RIDER
      debugPrint("========== RIDER DRIVER DATABASE CHECK ==========");
      debugPrint("Firebase initialized: ${FirebaseService.isFirebaseAvailable}");
      debugPrint("Firebase project ID: $laptopProjectId");

      try {
        final allDriversSnapshot = await FirebaseFirestore.instance
            .collection('drivers')
            .get()
            .timeout(const Duration(seconds: 15));
        debugPrint("Total driver documents: ${allDriversSnapshot.docs.length}");
        for (var doc in allDriversSnapshot.docs) {
          final data = doc.data();
          debugPrint("driverId: ${doc.id}");
          debugPrint("isOnline: ${data['isOnline']} (${data['isOnline']?.runtimeType})");
          debugPrint("isAvailable: ${data['isAvailable']} (${data['isAvailable']?.runtimeType})");
          debugPrint("vehicleType: ${data['vehicleType']} (${data['vehicleType']?.runtimeType})");
          debugPrint("latitude: ${data['currentLatitude']} (${data['currentLatitude']?.runtimeType})");
          debugPrint("longitude: ${data['currentLongitude']} (${data['currentLongitude']?.runtimeType})");
        }
      } catch (e) {
        debugPrint("STEP 1: Direct read of /drivers failed with exception:");
        debugPrint("$e");
        if (e is FirebaseException) {
          debugPrint("Error Code: ${e.code}");
        }
      }

      // STEP 2 — READ THE SPECIFIC DRIVER
      debugPrint("========== SPECIFIC DRIVER CHECK ==========");
      String? driverProjectId;
      try {
        final specificDriverSnapshot = await FirebaseFirestore.instance
            .collection('drivers')
            .doc('d_ramesh')
            .get()
            .timeout(const Duration(seconds: 15));
        
        final docExists = specificDriverSnapshot.exists;
        debugPrint("Document exists: $docExists");
        if (docExists) {
          final data = specificDriverSnapshot.data()!;
          debugPrint("driverId: d_ramesh");
          debugPrint("isOnline: ${data['isOnline']} (${data['isOnline']?.runtimeType})");
          debugPrint("isAvailable: ${data['isAvailable']} (${data['isAvailable']?.runtimeType})");
          debugPrint("vehicleType: ${data['vehicleType']} (${data['vehicleType']?.runtimeType})");
          debugPrint("currentLatitude: ${data['currentLatitude']} (${data['currentLatitude']?.runtimeType})");
          debugPrint("currentLongitude: ${data['currentLongitude']} (${data['currentLongitude']?.runtimeType})");
          
          driverProjectId = data['projectId'] as String?;
        }
      } catch (e) {
        debugPrint("STEP 2: Direct read of /drivers/d_ramesh failed with exception:");
        debugPrint("$e");
        if (e is FirebaseException) {
          debugPrint("Error Code: ${e.code}");
        }
      }

      // STEP 3 — COMPARE FIREBASE PROJECTS
      debugPrint("========== FIREBASE PROJECT COMPARISON ==========");
      debugPrint("ANDROID: Firebase project ID: ${driverProjectId ?? 'Unknown (not written/read yet)'}");
      debugPrint("LAPTOP: Firebase project ID: $laptopProjectId");
      if (driverProjectId != null && driverProjectId != laptopProjectId) {
        debugPrint("CRITICAL: ANDROID AND RIDER ARE USING DIFFERENT FIREBASE PROJECTS");
        _ref.read(rideErrorProvider.notifier).state = "ANDROID AND RIDER ARE USING DIFFERENT FIREBASE PROJECTS";
        state = state.copyWith(status: RiderStatus.noDriversAvailable);
        return; // STOP execution
      } else if (driverProjectId != null) {
        debugPrint("Firebase project ID comparison MATCHED: $laptopProjectId");
      }

      // STEP 4 — TEST THE QUERY & STEP 5 — CHECK FIELD TYPES
      debugPrint("========== DRIVER QUERY RESULT ==========");
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('drivers')
            .where('isOnline', isEqualTo: true)
            .where('isAvailable', isEqualTo: true)
            .where('vehicleType', isEqualTo: 'bike')
            .get()
            .timeout(const Duration(seconds: 15));
        
        debugPrint("Query returned: ${querySnapshot.docs.length}");
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          debugPrint("driverId: ${doc.id}");
          debugPrint("isOnline: ${data['isOnline']} (${data['isOnline']?.runtimeType})");
          debugPrint("isAvailable: ${data['isAvailable']} (${data['isAvailable']?.runtimeType})");
          debugPrint("vehicleType: ${data['vehicleType']} (${data['vehicleType']?.runtimeType})");
        }
      } catch (e) {
        debugPrint("STEP 4: Query execution failed with exception:");
        debugPrint("$e");
        if (e is FirebaseException) {
          debugPrint("Error Code: ${e.code}");
        }
      }
    }

    // 8. DRIVER QUERY
    debugPrint("Searching for online available drivers...");
    List<Map<String, dynamic>> eligibleDrivers = [];
    try {
      eligibleDrivers = await FirebaseService.queryEligibleDrivers();
      debugPrint("Drivers found: ${eligibleDrivers.length}");
      for (var driver in eligibleDrivers) {
        debugPrint("Driver ID: ${driver['driverId']}");
        debugPrint("Online: ${driver['isOnline']}");
        debugPrint("Available: ${driver['isAvailable']}");
        debugPrint("Vehicle type: ${driver['vehicleType']}");
        debugPrint("Latitude: ${driver['currentLatitude']}");
        debugPrint("Longitude: ${driver['currentLongitude']}");
      }
      if (eligibleDrivers.isEmpty) {
        debugPrint("========== NO ELIGIBLE DRIVERS ==========");
        debugPrint("No online and available bike drivers were found.");
        _ref.read(rideErrorProvider.notifier).state = "No eligible drivers found.";
      }
    } catch (e) {
      debugPrint("Driver query failed: $e");
      _ref.read(rideErrorProvider.notifier).state = "Failed to query drivers.";
      state = state.copyWith(status: RiderStatus.noDriversAvailable);
      return;
    }

    // Setup client-side visual fail-safe trigger (runs if no driver accepts within 61s)
    Timer(const Duration(seconds: 61), () {
      if (state.status == RiderStatus.searching) {
        debugPrint("No drivers available nearby");
        state = state.copyWith(status: RiderStatus.noDriversAvailable);
      }
    });

    // Listen to real-time status updates of the ride
    _rideSubscription = FirebaseService.streamRide(rideId).listen((rideDoc) {
      if (rideDoc.isEmpty) return;

      final String status = rideDoc['status'] as String? ?? 'searching';

      if (status == 'accepted' && state.status == RiderStatus.searching) {
        final driverId = rideDoc['driverId'] as String? ?? 'd_ramesh';
        final driverName = rideDoc['driverName'] as String? ?? 'Ramesh Kumar';
        final vehiclePlate = rideDoc['driverVehicleNumber'] as String? ?? 'KA-03-AB-1234';

        debugPrint("Driver accepted: $driverId. Status: searching -> accepted");

        final driver = Driver(
          id: driverId,
          name: driverName,
          phone: "+91 98765 43210",
          photoUrl: "",
          vehicleModel: "WagonR • White",
          vehiclePlate: vehiclePlate,
          rating: 4.8,
          currentLat: pickup.latitude + 0.012,
          currentLng: pickup.longitude + 0.012,
        );

        final activeRide = Ride(
          id: rideId,
          pickup: pickup,
          destination: destination,
          price: state.price,
          status: RiderStatus.accepted,
          otp: "1234",
          timestamp: DateTime.now(),
          driver: driver,
        );

        state = state.copyWith(
          status: RiderStatus.accepted,
          activeRide: () => activeRide,
        );

        _simulateDriverArriving();
      }
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

    // Call complete ride on Firebase Service to free up driver availability
    if (state.activeRide!.driver != null) {
      FirebaseService.completeRide(state.activeRide!.id, state.activeRide!.driver!.id);
    }
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
    _rideSubscription?.cancel();
    _simulationTimer?.cancel();
    
    // Set status to completed on Firebase if we have an active ride
    if (state.activeRide != null && state.activeRide!.driver != null) {
      FirebaseService.completeRide(state.activeRide!.id, state.activeRide!.driver!.id);
    }

    state = state.copyWith(
      status: RiderStatus.idle,
      activeRide: () => null,
      pickup: () => null,
      destination: () => null,
    );
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final rideBookingNotifierProvider = StateNotifierProvider<RideBookingNotifier, RideBookingState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RideBookingNotifier(prefs, ref);
});

final rideErrorProvider = StateProvider<String?>((ref) => null);
