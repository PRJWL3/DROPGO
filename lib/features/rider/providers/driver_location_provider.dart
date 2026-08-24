import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';

int _subscriptionCount = 0;

final onlineDriversProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (!FirebaseService.isFirebaseAvailable) {
    // In Mock Mode / Fallback Mode, return empty stream
    return Stream.value([]);
  }

  _subscriptionCount++;
  final currentCount = _subscriptionCount;
  debugPrint("DRIVER STREAM SUBSCRIPTION CREATED: $currentCount");
  debugPrint("DRIVER STREAM SUBSCRIBED");

  ref.onDispose(() {
    debugPrint("DRIVER STREAM DISPOSED");
  });

  return FirebaseFirestore.instance
      .collection('drivers')
      .where('isOnline', isEqualTo: true)
      .where('isAvailable', isEqualTo: true)
      .where('vehicleType', isEqualTo: 'bike')
      .snapshots()
      .map((snapshot) {
        final drivers = snapshot.docs.map((doc) => doc.data()).toList();
        return drivers;
      });
});

final assignedDriverLocationProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, driverId) {
  if (!FirebaseService.isFirebaseAvailable) {
    return Stream.value({});
  }

  return FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId)
      .snapshots()
      .map((doc) => doc.data() ?? {});
});
