import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';

final onlineDriversProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (!FirebaseService.isFirebaseAvailable) {
    // In Mock Mode / Fallback Mode, return empty stream
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('drivers')
      .where('isOnline', isEqualTo: true)
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final drivers = snapshot.docs.map((doc) => doc.data()).toList();
        debugPrint("ONLINE DRIVERS: ${drivers.length}");
        return drivers;
      });
});
