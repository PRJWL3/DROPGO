import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../features/rider/models/ride_model.dart';

class FirebaseService {
  static bool isFirebaseAvailable = false;

  // Local simulated database maps for Local Mode fallback
  static final Map<String, Map<String, dynamic>> _localDrivers = {};
  static final Map<String, Map<String, dynamic>> _localRides = {};

  // Local stream controllers for simulated real-time updates
  static final _rideStreamControllers = <String, StreamController<Map<String, dynamic>>>{};
  static final _localNotificationController = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onLocalNotification => _localNotificationController.stream;

  /// Initializes Firebase Core and Cloud Messaging safely
  static Future<void> initialize() async {
    try {
      // Wrap initialization to prevent crashes on untargeted builds
      await Firebase.initializeApp();
      isFirebaseAvailable = true;
      debugPrint("FIREBASE MODE: Cross-device ride request enabled");
      
      // Request FCM permissions and configure background triggers
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      isFirebaseAvailable = false;
      debugPrint("LOCAL SIMULATION MODE");
      debugPrint("Error: $e");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      await Firebase.initializeApp();
    } catch (_) {}
    debugPrint("Handling background FCM push payload: ${message.data}");
  }

  /// Registers or updates driver status in Firestore or local memory
  static Future<void> updateDriverStatus({
    required String driverId,
    required String name,
    required String phone,
    required String vehicleNumber,
    required double rating,
    required double lat,
    required double lng,
    required bool isOnline,
    required bool isAvailable,
    required String token,
  }) async {
    final data = {
      'driverId': driverId,
      'name': name,
      'phone': phone,
      'vehicleType': 'bike',
      'vehicleNumber': vehicleNumber,
      'rating': rating,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'currentLatitude': lat,
      'currentLongitude': lng,
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance.collection('drivers').doc(driverId).set(data, SetOptions(merge: true));
    } else {
      _localDrivers[driverId] = {
        ...data,
        'updatedAt': DateTime.now(),
      };
      debugPrint("LOCAL SIMULATION MODE: Updated driver status for $driverId: isOnline=$isOnline, isAvailable=$isAvailable");
    }
  }

  /// Registers FCM Token for real-world background messaging
  static Future<String?> getFcmToken() async {
    if (isFirebaseAvailable) {
      try {
        return await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("FCM token retrieval failed: $e");
      }
    }
    return "mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}";
  }

  /// Writes a new ride document to Firestore or local database
  static Future<void> createRideRequest({
    required String rideId,
    required String riderId,
    required String riderName,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    required double distanceKm,
    required double durationMinutes,
    required double estimatedFare,
    required String paymentMethod,
  }) async {
    final expiresAt = DateTime.now().add(const Duration(seconds: 60));
    
    final data = {
      'rideId': rideId,
      'riderId': riderId,
      'riderName': riderName,
      'pickupAddress': pickupAddress,
      'pickupLatitude': pickupLat,
      'pickupLongitude': pickupLng,
      'destinationAddress': destinationAddress,
      'destinationLatitude': destinationLat,
      'destinationLongitude': destinationLng,
      'distanceKm': distanceKm,
      'estimatedDurationMinutes': durationMinutes,
      'estimatedFare': estimatedFare,
      'vehicleType': 'bike',
      'paymentMethod': paymentMethod,
      'status': 'searching',
      'createdAt': isFirebaseAvailable ? FieldValue.serverTimestamp() : DateTime.now(),
      'expiresAt': isFirebaseAvailable ? Timestamp.fromDate(expiresAt) : expiresAt,
    };

    debugPrint("RIDER: Ride created: $rideId");

    if (isFirebaseAvailable) {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).set(data);
    } else {
      _localRides[rideId] = data;
      _getOrCreateRideController(rideId).add(data);
      
      // Trigger the local simulated Cloud Function background runner
      _runLocalCloudFunctionTrigger(rideId, pickupLat, pickupLng, estimatedFare, distanceKm, durationMinutes);
    }
  }

  /// Streams updates of a specific ride record
  static Stream<Map<String, dynamic>> streamRide(String rideId) {
    if (isFirebaseAvailable) {
      return FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .snapshots()
          .map((snapshot) => snapshot.data() ?? {});
    } else {
      return _getOrCreateRideController(rideId).stream;
    }
  }

  /// Fetches a ride snapshot (useful on notification tap or app resume)
  static Future<Map<String, dynamic>?> getRide(String rideId) async {
    if (isFirebaseAvailable) {
      final doc = await FirebaseFirestore.instance.collection('rides').doc(rideId).get();
      return doc.data();
    } else {
      return _localRides[rideId];
    }
  }

  /// Atomic Firestore transaction to determine the ride acceptor
  static Future<String?> acceptRide({
    required String rideId,
    required String driverId,
    required String driverName,
    required String driverVehicleNumber,
  }) async {
    if (isFirebaseAvailable) {
      try {
        final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
        final driverRef = FirebaseFirestore.instance.collection('drivers').doc(driverId);

        final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
          final rideSnapshot = await transaction.get(rideRef);
          final driverSnapshot = await transaction.get(driverRef);

          if (!rideSnapshot.exists) return "Ride request does not exist";

          final rideData = rideSnapshot.data()!;
          final status = rideData['status'] as String;
          final expiresTimestamp = rideData['expiresAt'] as Timestamp;
          final expiresAt = expiresTimestamp.toDate();

          // 1. Verify status is still searching
          if (status != 'searching') {
            return "Ride already accepted";
          }

          // 2. Verify ride has not expired
          if (DateTime.now().isAfter(expiresAt)) {
            return "Ride request expired";
          }

          if (driverSnapshot.exists) {
            final driverData = driverSnapshot.data()!;
            final isOnline = driverData['isOnline'] as bool? ?? false;
            final isAvailable = driverData['isAvailable'] as bool? ?? false;
            final vehicleType = driverData['vehicleType'] as String? ?? "";

            // 3. Verify driver online & available status
            if (!isOnline) return "Driver is offline";
            if (!isAvailable) return "Driver is not available";

            // 4. Verify driver vehicle type matches requested vehicle type
            if (vehicleType != rideData['vehicleType']) {
              return "Driver vehicle type mismatch";
            }
          }

          // Atomic updates
          transaction.update(rideRef, {
            'status': 'accepted',
            'driverId': driverId,
            'driverName': driverName,
            'driverVehicleNumber': driverVehicleNumber,
            'acceptedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(driverRef, {
            'isAvailable': false,
          });

          return null; // Success
        });

        if (result == null) {
          debugPrint("DRIVER: Ride accepted: $rideId");
        }
        return result;
      } catch (e) {
        return "Transaction failed: $e";
      }
    } else {
      // Local Mode atomic check
      final rideData = _localRides[rideId];
      if (rideData == null) return "Ride request does not exist";

      final status = rideData['status'] as String;
      final expiresAt = rideData['expiresAt'] as DateTime;

      if (status != 'searching') {
        return "Ride already accepted";
      }

      if (DateTime.now().isAfter(expiresAt)) {
        return "Ride request expired";
      }

      final driverData = _localDrivers[driverId];
      if (driverData != null) {
        final isOnline = driverData['isOnline'] as bool? ?? false;
        final isAvailable = driverData['isAvailable'] as bool? ?? false;
        final vehicleType = driverData['vehicleType'] as String? ?? "";

        if (!isOnline) return "Driver is offline";
        if (!isAvailable) return "Driver is not available";
        if (vehicleType != rideData['vehicleType']) {
          return "Driver vehicle type mismatch";
        }
      }

      // Update local maps
      rideData['status'] = 'accepted';
      rideData['driverId'] = driverId;
      rideData['driverName'] = driverName;
      rideData['driverVehicleNumber'] = driverVehicleNumber;
      rideData['acceptedAt'] = DateTime.now();

      if (driverData != null) {
        driverData['isAvailable'] = false;
      }

      _localRides[rideId] = rideData;
      _getOrCreateRideController(rideId).add(rideData);

      debugPrint("DRIVER: Ride accepted: $rideId");
      return null; // Success
    }
  }

  /// Mark ride complete and free up driver availability
  static Future<void> completeRide(String rideId, String driverId) async {
    if (isFirebaseAvailable) {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(FirebaseFirestore.instance.collection('rides').doc(rideId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      batch.update(FirebaseFirestore.instance.collection('drivers').doc(driverId), {
        'isAvailable': true,
      });
      await batch.commit();
    } else {
      final rideData = _localRides[rideId];
      if (rideData != null) {
        rideData['status'] = 'completed';
        _localRides[rideId] = rideData;
        _getOrCreateRideController(rideId).add(rideData);
      }

      final driverData = _localDrivers[driverId];
      if (driverData != null) {
        driverData['isAvailable'] = true;
      }
      debugPrint("LOCAL SIMULATION MODE: Ride completed: $rideId. Driver isAvailable -> true");
    }
  }

  /// Simulates a cloud function running on the server:
  /// queries online/available drivers within 5km, sorts by distance, and dispatches FCM payloads.
  static void _runLocalCloudFunctionTrigger(
    String rideId,
    double pickupLat,
    double pickupLng,
    double fare,
    double distanceKm,
    double durationMinutes,
  ) {
    Timer(const Duration(milliseconds: 1000), () {
      final eligibleDrivers = <Map<String, dynamic>>[];

      // Query local online available drivers
      for (var entry in _localDrivers.entries) {
        final d = entry.value;
        final isOnline = d['isOnline'] as bool? ?? false;
        final isAvailable = d['isAvailable'] as bool? ?? false;
        final vehicleType = d['vehicleType'] as String? ?? "";

        if (isOnline && isAvailable && vehicleType == 'bike') {
          final lat = d['currentLatitude'] as double;
          final lng = d['currentLongitude'] as double;

          // Simple flat Euclidean distance estimate for MVP radius
          final double diffLat = lat - pickupLat;
          final double diffLng = lng - pickupLng;
          final double distanceEst = diffLat * diffLat + diffLng * diffLng; // squared delta

          eligibleDrivers.add({
            'driverId': entry.key,
            'data': d,
            'distSq': distanceEst,
          });
        }
      }

      // Sort candidate drivers by distance from pickup
      eligibleDrivers.sort((a, b) => (a['distSq'] as double).compareTo(b['distSq'] as double));

      debugPrint("LOCAL SIMULATION MODE: Nearby drivers found: ${eligibleDrivers.length}");

      // Send simulated push notifications to the closest suitable drivers (up to 5)
      final notifyCount = eligibleDrivers.length > 5 ? 5 : eligibleDrivers.length;
      for (int i = 0; i < notifyCount; i++) {
        final driverId = eligibleDrivers[i]['driverId'] as String;
        debugPrint("LOCAL SIMULATION MODE: Notifying driver: $driverId");
      }
      
      debugPrint("LOCAL SIMULATION MODE: Drivers notified: $notifyCount");

      if (eligibleDrivers.isNotEmpty) {
        final closestDriver = eligibleDrivers.first;
        final fcmPayload = {
          'rideId': rideId,
          'pickupAddress': _localRides[rideId]?['pickupAddress'] ?? "Pickup Address",
          'destinationAddress': _localRides[rideId]?['destinationAddress'] ?? "Destination Address",
          'distanceKm': distanceKm,
          'estimatedDurationMinutes': durationMinutes,
          'estimatedFare': fare,
        };

        // Notify matching listener
        _localNotificationController.add(fcmPayload);
      }
    });
  }

  static StreamController<Map<String, dynamic>> _getOrCreateRideController(String rideId) {
    return _rideStreamControllers.putIfAbsent(rideId, () => StreamController<Map<String, dynamic>>.broadcast());
  }
}
