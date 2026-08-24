import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../features/rider/models/ride_model.dart';
import '../../../firebase_options.dart';

class FirebaseService {
  static bool isFirebaseAvailable = false;
  static String? initializationError;

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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      isFirebaseAvailable = true;
      initializationError = null;
      
      String projectId = "Unknown";
      try {
        projectId = Firebase.app().options.projectId;
      } catch (_) {}
      
      debugPrint("FIREBASE INITIALIZED");
      debugPrint("FIREBASE MODE");
      debugPrint("Firebase Project ID: $projectId");

      if (kIsWeb) {
        debugPrint("========== WEB FIREBASE DEBUG ==========");
        debugPrint("Firebase initialized:\ntrue\n");
        debugPrint("Firebase project ID:\n$projectId\n");
        debugPrint("Firestore instance:\navailable");
      }
      
      // Run Firestore Diagnostic Test (non-fatal)
      try {
        await runFirestoreDiagnostic("diag_${DateTime.now().millisecondsSinceEpoch}");
      } catch (diagError) {
        debugPrint("Firestore diagnostic test warning: $diagError");
      }

      // Safeguard Firebase Messaging (non-fatal, especially on web/desktop)
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          provisional: false,
          sound: true,
        );

        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (msgError) {
        debugPrint("Firebase Messaging initialization warning (non-fatal): $msgError");
      }
    } catch (e) {
      isFirebaseAvailable = false;
      initializationError = e.toString();
      debugPrint("FIREBASE INITIALIZATION FAILED. Error: $e");
      if (kIsWeb) {
        debugPrint("========== WEB FIREBASE DEBUG ==========");
        debugPrint("Firebase initialized:\nfalse\n");
        debugPrint("Firebase project ID:\nUnknown\n");
        debugPrint("Firestore instance:\nunavailable");
      }
      debugPrint("LOCAL SIMULATION MODE");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}
    debugPrint("Handling background FCM push payload: ${message.data}");
  }

  /// Runs connection diagnostic write, read, and delete tests
  static Future<void> runFirestoreDiagnostic(String deviceId) async {
    if (!isFirebaseAvailable) {
      debugPrint("Diagnostic skipped: Firebase not initialized.");
      return;
    }
    
    String platform = 'unknown';
    if (kIsWeb) {
      platform = 'web';
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        platform = 'android';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
      } else {
        platform = defaultTargetPlatform.toString().split('.').last.toLowerCase();
      }
    }

    final ref = FirebaseFirestore.instance.collection('connection_test').doc(deviceId);
    
    // Test Write
    bool writeSuccess = false;
    try {
      await ref.set({
        'test': 'success',
        'timestamp': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      writeSuccess = true;
    } catch (e) {
      debugPrint("Firestore write failed during test: $e");
    }

    // Test Read
    bool readSuccess = false;
    if (writeSuccess) {
      try {
        final doc = await ref.get().timeout(const Duration(seconds: 15));
        if (doc.exists && doc.data()?['test'] == 'success') {
          readSuccess = true;
        }
      } catch (e) {
        debugPrint("Firestore read failed during test: $e");
      }
    }

    // Test Delete
    bool deleteSuccess = false;
    try {
      await ref.delete().timeout(const Duration(seconds: 15));
      deleteSuccess = true;
    } catch (e) {
      debugPrint("Firestore delete failed during test: $e");
    }

    debugPrint("========== FIREBASE CONNECTION TEST ==========");
    debugPrint("Platform: $platform");
    debugPrint("Firebase initialized: YES");
    debugPrint("Project ID: dropgo-fa413");
    debugPrint("Firestore write: ${writeSuccess ? 'SUCCESS' : 'FAILED'}");
    debugPrint("Firestore read: ${readSuccess ? 'SUCCESS' : 'FAILED'}");
    debugPrint("Firestore delete: ${deleteSuccess ? 'SUCCESS' : 'FAILED'}");
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
      'projectId': isFirebaseAvailable ? Firebase.app().options.projectId : "local",
      'updatedAt': isFirebaseAvailable ? FieldValue.serverTimestamp() : DateTime.now(),
    };

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('drivers').doc(driverId);
        
        // Write to Firestore with 15s timeout
        await docRef.set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
        
        // Immediately read back to verify existence
        final snapshot = await docRef.get().timeout(const Duration(seconds: 15));
        final exists = snapshot.exists;
        
        debugPrint("Driver document exists:\n$exists\n");
        if (exists) {
          final readData = snapshot.data();
          debugPrint("isOnline:\n${readData?['isOnline']}\n");
          debugPrint("isAvailable:\n${readData?['isAvailable']}\n");
          debugPrint("vehicleType:\n${readData?['vehicleType']}");
        }
        
        if (!exists) {
          throw Exception("Document readback returned empty/non-existent");
        }
      } catch (e) {
        if (e.toString().contains("permission-denied") || e.toString().contains("permission_denied")) {
          debugPrint("PERMISSION-DENIED: Failed during updateDriverStatus. Error: $e");
        } else if (e is TimeoutException) {
          debugPrint("Connection timed out. Check Firebase connection.");
        }
        rethrow;
      }
    } else {
      _localDrivers[driverId] = data;
      
      debugPrint("Driver ID: $driverId");
      debugPrint("Driver Firestore path: /drivers/$driverId");
      debugPrint("Driver online: $isOnline");
      debugPrint("Driver available: $isAvailable");
      debugPrint("Driver vehicle type: bike");
      debugPrint("Driver location: ($lat, $lng)");
      debugPrint("Driver document successfully written: true");
    }
  }

  /// Queries for active and available bike drivers
  static Future<List<Map<String, dynamic>>> queryEligibleDrivers() async {
    if (!isFirebaseAvailable) {
      return _localDrivers.values.where((d) =>
        d['isOnline'] == true &&
        d['isAvailable'] == true &&
        d['vehicleType'] == 'bike'
      ).cast<Map<String, dynamic>>().toList();
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .where('vehicleType', isEqualTo: 'bike')
          .get()
          .timeout(const Duration(seconds: 15));
          
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (e.toString().contains("permission-denied") || e.toString().contains("permission_denied")) {
        debugPrint("PERMISSION-DENIED: Failed to query drivers from Firestore");
      } else if (e is TimeoutException) {
        debugPrint("Connection timed out. Check Firebase connection.");
      }
      rethrow;
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

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('rides').doc(rideId).set(data).timeout(const Duration(seconds: 15));
        
        final snapshot = await FirebaseFirestore.instance.collection('rides').doc(rideId).get().timeout(const Duration(seconds: 15));
        final exists = snapshot.exists;
        debugPrint("Ride document written & verified read: $exists");
        if (exists) {
          final readData = snapshot.data();
          debugPrint("Ride ID: ${readData?['rideId']}");
          debugPrint("Rider Name: ${readData?['riderName']}");
          debugPrint("Status: ${readData?['status']}");
        }
      } catch (e) {
        if (e.toString().contains("permission-denied") || e.toString().contains("permission_denied")) {
          debugPrint("PERMISSION-DENIED: Failed during createRideRequest write. Error: $e");
        } else if (e is TimeoutException) {
          debugPrint("Connection timed out. Check Firebase connection.");
        }
        rethrow;
      }
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
      try {
        final doc = await FirebaseFirestore.instance.collection('rides').doc(rideId).get().timeout(const Duration(seconds: 15));
        return doc.data();
      } catch (e) {
        if (e.toString().contains("permission-denied") || e.toString().contains("permission_denied")) {
          debugPrint("PERMISSION-DENIED: Failed during getRide. Error: $e");
        } else if (e is TimeoutException) {
          debugPrint("Connection timed out. Check Firebase connection.");
        }
        rethrow;
      }
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
    // Generate the random 4-digit OTP ONCE before the transaction starts (Step 1)
    final String generatedOtp = (1000 + Random().nextInt(9000)).toString();

    if (isFirebaseAvailable) {
      try {
        final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
        final driverRef = FirebaseFirestore.instance.collection('drivers').doc(driverId);
 
        // Pre-fetch initial states for ACCEPT RIDE DEBUG logging
        final initialDriverSnap = await driverRef.get();
        final initialRideSnap = await rideRef.get();
        final driverOnlineBefore = initialDriverSnap.exists ? (initialDriverSnap.data()?['isOnline'] as bool? ?? false) : false;
        final driverAvailableBefore = initialDriverSnap.exists ? (initialDriverSnap.data()?['isAvailable'] as bool? ?? false) : false;
        final rideStatusBefore = initialRideSnap.exists ? (initialRideSnap.data()?['status'] as String? ?? 'none') : 'none';

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
 
          // Atomic updates - Only write the generated OTP if status == "searching" (Step 2)
          transaction.update(rideRef, {
            'status': 'accepted',
            'driverId': driverId,
            'driverName': driverName,
            'driverVehicleNumber': driverVehicleNumber,
            'acceptedAt': FieldValue.serverTimestamp(),
            'otp': generatedOtp, // Step 4
          });
 
          transaction.update(driverRef, {
            'isAvailable': false,
          });
 
          return null; // Success
        }).timeout(const Duration(seconds: 15));
 
        // Post-fetch updated availability
        final updatedDriverSnap = await driverRef.get();
        final updatedAvailable = updatedDriverSnap.exists ? (updatedDriverSnap.data()?['isAvailable'] as bool? ?? false) : false;

        debugPrint("========== ACCEPT RIDE DEBUG ==========");
        debugPrint("Driver ID: $driverId");
        debugPrint("Driver isOnline: $driverOnlineBefore");
        debugPrint("Driver isAvailable: $driverAvailableBefore");
        debugPrint("Ride ID: $rideId");
        debugPrint("Ride status: $rideStatusBefore");
        debugPrint("Acceptance result: ${result ?? 'SUCCESS'}");
        debugPrint("Updated driver availability: $updatedAvailable");
        debugPrint("=======================================");

        if (result == null) {
          debugPrint("DRIVER: Ride accepted: $rideId");
        }
        return result;
      } catch (e) {
        if (e.toString().contains("permission-denied") || e.toString().contains("permission_denied")) {
          debugPrint("PERMISSION-DENIED: Failed during acceptRide transaction. Error: $e");
        } else if (e is TimeoutException) {
          debugPrint("Connection timed out. Check Firebase connection.");
          return "Connection timed out. Check Firebase connection.";
        }
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
      rideData['otp'] = generatedOtp;
 
      if (driverData != null) {
        driverData['isAvailable'] = false;
      }
 
      _localRides[rideId] = rideData;
      _getOrCreateRideController(rideId).add(rideData);
 
      debugPrint("DRIVER: Ride accepted: $rideId");
      return null; // Success
    }
  }

  /// Atomic Firestore transaction to verify Rider OTP and start trip (Step 10 & 11)
  static Future<String?> verifyRideOtp({
    required String rideId,
    required String driverId,
    required String submittedOtp,
  }) async {
    if (isFirebaseAvailable) {
      try {
        final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
        
        final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
          final rideSnapshot = await transaction.get(rideRef);
          if (!rideSnapshot.exists) {
            return "Ride request does not exist";
          }
          
          final rideData = rideSnapshot.data()!;
          final status = rideData['status'] as String? ?? '';
          final storedDriverId = rideData['driverId'] as String? ?? '';
          final storedOtp = rideData['otp'] as String? ?? '';
          
          // Validation checks (Step 10)
          if (status != 'accepted' && status != 'driver_arrived') {
            return "Ride is not in accepted or driver_arrived state";
          }
          if (storedDriverId != driverId) {
            return "Unauthorized driver for this ride";
          }
          if (storedOtp != submittedOtp) {
            return "Incorrect OTP";
          }
          
          // Atomic update on success (Step 11)
          transaction.update(rideRef, {
            'status': 'in_progress',
            'startedAt': FieldValue.serverTimestamp(),
          });
          
          return null; // Success
        }).timeout(const Duration(seconds: 15));
        
        return result;
      } catch (e) {
        if (e.toString().contains("permission-denied") || e.toString().contains("permission_denied")) {
          return "PERMISSION-DENIED: verifyRideOtp. Error: $e";
        }
        return "Transaction failed: $e";
      }
    } else {
      // Local Mode verification fallback
      final rideData = _localRides[rideId];
      if (rideData == null) return "Ride request does not exist";
      
      final status = rideData['status'] as String? ?? '';
      final storedDriverId = rideData['driverId'] as String? ?? '';
      final storedOtp = rideData['otp'] as String? ?? '';
      
      if (status != 'accepted' && status != 'driver_arrived') {
        return "Ride is not in accepted or driver_arrived state";
      }
      if (storedDriverId != driverId) {
        return "Unauthorized driver for this ride";
      }
      if (storedOtp != submittedOtp) {
        return "Incorrect OTP";
      }
      
      rideData['status'] = 'in_progress';
      rideData['startedAt'] = DateTime.now();
      
      _localRides[rideId] = rideData;
      _getOrCreateRideController(rideId).add(rideData);
      
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
          final lat = (d['currentLatitude'] as num).toDouble();
          final lng = (d['currentLongitude'] as num).toDouble();

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
      eligibleDrivers.sort((a, b) => ((a['distSq'] as num).toDouble()).compareTo((b['distSq'] as num).toDouble()));

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
