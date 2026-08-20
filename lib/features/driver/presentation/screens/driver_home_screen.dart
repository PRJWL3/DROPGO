// Driver home screen displaying earnings statistics, online toggles, and nearby ride requests
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../rider/presentation/widgets/app_top_bar.dart';
import '../../../rider/presentation/widgets/bottom_nav_bar.dart';
import '../../../rider/presentation/widgets/map_preview.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/services/firebase_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isOnline = false;
  int _currentNavIndex = 0;
  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  StreamSubscription? _firestoreRidesSubscription;
  Position? _lastUpdatedPosition;
  DateTime? _lastUpdateTime;
  String? _fcmToken;

  final Set<String> _notifiedRideIds = {};
  List<Map<String, dynamic>> _searchingRidesList = [];

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _fcmSubscription?.cancel();
    _firestoreRidesSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }



  void _toggleOnlineStatus(bool val) async {
    _positionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _fcmSubscription?.cancel();
    _firestoreRidesSubscription?.cancel();
    
    _positionSubscription = null;
    _notificationSubscription = null;
    _fcmSubscription = null;
    _firestoreRidesSubscription = null;
    
    _lastUpdatedPosition = null;
    _lastUpdateTime = null;

    if (val) {
      debugPrint("DRIVER ONLINE: d_ramesh");
      
      try {
        _fcmToken = await FirebaseService.getFcmToken().timeout(const Duration(seconds: 15));
        
        // Step 2: Immediate driver status registration & readback validation
        await FirebaseService.updateDriverStatus(
          driverId: "d_ramesh",
          name: "Ramesh Kumar",
          phone: "+91 98765 43210",
          vehicleNumber: "KA-05-AA-5678",
          rating: 4.8,
          lat: 12.9716,
          lng: 77.5946,
          isOnline: true,
          isAvailable: true,
          token: _fcmToken ?? "mock_token",
        ).timeout(const Duration(seconds: 15));
        debugPrint("DRIVER LOCATION: 12.9716, 77.5946");
        
        debugPrint("========== DRIVER LISTENER STARTED ==========");
        debugPrint("Driver ID: d_ramesh");
        debugPrint("Listening for searching bike rides...");
      } catch (e) {
        debugPrint("Driver registration failed: $e");
        if (mounted) {
          setState(() {
            _isOnline = false;
          });
          context.showSnackBar("Unable to connect to driver service", backgroundColor: Colors.red);
        }
        return; // Abort further updates/listeners
      }

      final service = ref.read(locationServiceProvider);
      // Listen for GPS updates (throttled every 10 seconds or 50 meters)
      _positionSubscription = service.getPositionStream().listen((position) async {
        if (!mounted || !_isOnline) return;

        bool shouldUpdate = false;
        final now = DateTime.now();

        if (_lastUpdatedPosition == null || _lastUpdateTime == null) {
          shouldUpdate = true;
        } else {
          final elapsedSec = now.difference(_lastUpdateTime!).inSeconds;
          final distanceMoved = Geolocator.distanceBetween(
            _lastUpdatedPosition!.latitude,
            _lastUpdatedPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (elapsedSec >= 10 || distanceMoved >= 50) {
            shouldUpdate = true;
          }
        }

        if (shouldUpdate) {
          _lastUpdatedPosition = position;
          _lastUpdateTime = now;

          try {
            await FirebaseService.updateDriverStatus(
              driverId: "d_ramesh",
              name: "Ramesh Kumar",
              phone: "+91 98765 43210",
              vehicleNumber: "KA-05-AA-5678",
              rating: 4.8,
              lat: position.latitude,
              lng: position.longitude,
              isOnline: true,
              isAvailable: true,
              token: _fcmToken ?? "mock_token",
            ).timeout(const Duration(seconds: 15));
            debugPrint("DRIVER LOCATION: ${position.latitude}, ${position.longitude}");
          } catch (e) {
            debugPrint("Throttled driver status update failed: $e");
          }
        }
      });

      if (FirebaseService.isFirebaseAvailable) {
        try {
          if (kIsWeb) {
            debugPrint("========== WEB RIDE LISTENER ==========");
            debugPrint("Attempting to start listener...");
          }

          final query = FirebaseFirestore.instance
              .collection('rides')
              .where('status', isEqualTo: 'searching')
              .where('vehicleType', isEqualTo: 'bike');

          // Log project ID for Step 9
          final String driverProjectId = Firebase.app().options.projectId;
          debugPrint("DRIVER: Firebase project ID: $driverProjectId");

          // Step 7: Initial fetch of currently active requests
          final initialSnapshot = await query.get().timeout(const Duration(seconds: 15));
          final existingRides = initialSnapshot.docs.where((doc) {
            final data = doc.data();
            final expiresTimestamp = data['expiresAt'] as Timestamp?;
            if (expiresTimestamp == null) return false;
            return expiresTimestamp.toDate().isAfter(DateTime.now());
          }).toList();

          if (kIsWeb) {
            debugPrint("Ride snapshot received");
            debugPrint("Total documents:\n${existingRides.length}\n");
            for (var doc in existingRides) {
              final data = doc.data();
              debugPrint("rideId: ${doc.id}");
              debugPrint("status: ${data['status']}");
              debugPrint("vehicleType: ${data['vehicleType']}");
              debugPrint("expiresAt: ${data['expiresAt']}");
            }
          }

          debugPrint("Searching rides received: ${existingRides.length}");

          for (var doc in existingRides) {
            final rideId = doc.id;
            if (!_notifiedRideIds.contains(rideId)) {
              _notifiedRideIds.add(rideId);
              
              final data = doc.data();
              debugPrint("========== NEW RIDE DETECTED ==========");
              debugPrint("Ride ID: $rideId");
              debugPrint("Pickup: ${data['pickupAddress']}");
              debugPrint("Destination: ${data['destinationAddress']}");
              debugPrint("Fare: ${data['estimatedFare']}");

              debugPrint("DRIVER: New ride detected: $rideId");
              debugPrint("DRIVER: Showing ride request: $rideId");
              
              // Prompt incoming request overlay
              Navigator.pushNamed(context, '/incoming-request', arguments: rideId);
            }
          }

          if (mounted) {
            setState(() {
              _searchingRidesList = existingRides.map((doc) => doc.data()).toList();
            });
          }

          // Step 3 & 7: Listen for live updates on new searching requests
          _firestoreRidesSubscription = query.snapshots().listen((snapshot) {
            if (!mounted || !_isOnline) return;

            final activeRides = snapshot.docs.where((doc) {
              final data = doc.data();
              final expiresTimestamp = data['expiresAt'] as Timestamp?;
              if (expiresTimestamp == null) return false;
              return expiresTimestamp.toDate().isAfter(DateTime.now());
            }).toList();

            if (kIsWeb) {
              debugPrint("Ride snapshot received");
              debugPrint("Total documents:\n${activeRides.length}\n");
              for (var doc in activeRides) {
                final data = doc.data();
                debugPrint("rideId: ${doc.id}");
                debugPrint("status: ${data['status']}");
                debugPrint("vehicleType: ${data['vehicleType']}");
                debugPrint("expiresAt: ${data['expiresAt']}");
              }
            }

            debugPrint("Searching rides received: ${activeRides.length}");

            for (var doc in activeRides) {
              final rideId = doc.id;
              if (!_notifiedRideIds.contains(rideId)) {
                _notifiedRideIds.add(rideId);
                
                final data = doc.data();
                debugPrint("========== NEW RIDE DETECTED ==========");
                debugPrint("Ride ID: $rideId");
                debugPrint("Pickup: ${data['pickupAddress']}");
                debugPrint("Destination: ${data['destinationAddress']}");
                debugPrint("Fare: ${data['estimatedFare']}");

                debugPrint("DRIVER: New ride detected: $rideId");
                debugPrint("DRIVER: Showing ride request: $rideId");
                
                // Prompt incoming request overlay
                Navigator.pushNamed(context, '/incoming-request', arguments: rideId);
              }
            }

            if (mounted) {
              setState(() {
                _searchingRidesList = activeRides.map((doc) => doc.data()).toList();
              });
            }
          }, onError: (e) {
            debugPrint("Listener failed:\n$e\n");
            if (e is FirebaseException) {
              debugPrint("Error code:\n${e.code}\n");
            }
          });

          if (kIsWeb) {
            debugPrint("Listener started successfully");
            debugPrint("Listening for rides: YES");
          }
        } catch (e) {
          debugPrint("Listener failed:\n$e\n");
          if (e is FirebaseException) {
            debugPrint("Error code:\n${e.code}\n");
          }
        }
      } else {
        // Fallback Local Simulation Mode
        _notificationSubscription = FirebaseService.onLocalNotification.listen((payload) {
          if (!mounted || !_isOnline) return;
          final rideId = payload['rideId'] as String;

          if (!_notifiedRideIds.contains(rideId)) {
            _notifiedRideIds.add(rideId);
            debugPrint("DRIVER: Active searching rides: 1");
            debugPrint("DRIVER: New ride detected: $rideId");
            debugPrint("DRIVER: Showing ride request: $rideId");

            Navigator.pushNamed(context, '/incoming-request', arguments: rideId);

            setState(() {
              _searchingRidesList = [payload];
            });
          }
        });
      }
    } else {
      // Driver going offline: update online status to false and stop location stream
      try {
        await FirebaseService.updateDriverStatus(
          driverId: "d_ramesh",
          name: "Ramesh Kumar",
          phone: "+91 98765 43210",
          vehicleNumber: "KA-05-AA-5678",
          rating: 4.8,
          lat: _lastUpdatedPosition?.latitude ?? 12.9716,
          lng: _lastUpdatedPosition?.longitude ?? 77.5946,
          isOnline: false,
          isAvailable: false,
          token: _fcmToken ?? "mock_token",
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint("Offline status update failed: $e");
      }
      
      if (mounted) {
        setState(() {
          _searchingRidesList = [];
        });
      }
    }
  }

  Widget _buildRealRequestCard(String rideId, String pickup, double fare, AppModeColors activeColors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: activeColors.elevatedCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: activeColors.primary.withOpacity(0.2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RIDE REQUEST • Live",
                style: TextStyle(
                  color: activeColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeColors.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Est. ₹${fare.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: activeColors.isDark ? Colors.white : const Color(0xFFD97706),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: activeColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: activeColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _searchingRidesList.removeWhere((r) => r['rideId'] == rideId);
                    });
                    context.showSnackBar("Request declined");
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: activeColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Decline",
                    style: TextStyle(color: activeColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/incoming-request', arguments: rideId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      backgroundColor: activeColors.background,
      body: Column(
        children: [
          // 1. Unified App Mode Top Bar
          AppTopBar(
            onMenuTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            onNotificationTap: () {
              context.showSnackBar("You have 3 new notifications");
            },
            notificationCount: 3,
          ),

          // 2. Main content scroll area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Today's Earnings and Stats Gradient Card (dynamic blue gradient in driver mode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🔧 DRIVER MODE FIRESTORE DEBUG PANEL",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text("Firebase initialized: ${FirebaseService.isFirebaseAvailable ? "YES" : "NO"}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("Firestore write: ${_isOnline ? "SUCCESS" : "INACTIVE"}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("Driver registered: ${_isOnline ? "YES" : "NO"}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("Ride listener: ${_firestoreRidesSubscription != null ? "ACTIVE" : "INACTIVE"}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("Listening for rides: ${(_isOnline && _firestoreRidesSubscription != null) ? "YES" : "NO"}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text("Active searching rides: ${_searchingRidesList.length}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: activeColors.isDark
                            ? [const Color(0xFF2563EB), const Color(0xFF60A5FA)]
                            : [const Color(0xFF1565FF), const Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: activeColors.primary.withOpacity(0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TODAY'S EARNINGS",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "₹860",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(height: 24, color: Colors.white24, thickness: 1.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCardStat("Trips completed", "12"),
                            _buildCardStat("Online time", "5h 20m"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Online Toggle Row (iOS-style switch container)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: activeColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: activeColors.border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), // success green dot
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnline ? "Online" : "Offline",
                              style: TextStyle(
                                color: _isOnline ? activeColors.primary : activeColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        // iOS-style switch
                        Switch.adaptive(
                          value: _isOnline,
                          activeColor: activeColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _isOnline = val;
                            });
                            _toggleOnlineStatus(val);
                            context.showSnackBar(
                              _isOnline ? "You are now ONLINE" : "You are now OFFLINE",
                              backgroundColor: _isOnline ? const Color(0xFF10B981) : activeColors.textSecondary,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Map card container
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: activeColors.border, width: 1.2),
                    ),
                    child: !isGoogleMapsInitialized()
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text("Initializing Maps API...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              ],
                            ),
                          )
                        : ref.watch(liveLocationProvider).when(
                            data: (position) {
                        if (_isOnline && _mapController != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _mapController!.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: LatLng(position.latitude, position.longitude),
                                  zoom: 16.0,
                                ),
                              ),
                            );
                          });
                        }

                        final carMarker = Marker(
                          markerId: const MarkerId("driver_car"),
                          position: LatLng(position.latitude, position.longitude),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          infoWindow: const InfoWindow(title: "My Vehicle"),
                        );

                        return GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(position.latitude, position.longitude),
                            zoom: 16.0,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          zoomControlsEnabled: false,
                          markers: {carMarker},
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                        );
                      },
                      error: (err, stack) => Container(
                        color: activeColors.cardBackground,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_rounded, color: activeColors.primary, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              "Enable location services to view map updates",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: activeColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Stats Grid Section
                  Text(
                    "Quick Stats",
                    style: TextStyle(
                      color: activeColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildQuickStatTile(Icons.account_balance_wallet_rounded, "Wallet", "₹860", activeColors),
                      _buildQuickStatTile(Icons.star_rounded, "Ratings", "4.9", activeColors),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickStatTile(Icons.local_gas_station_rounded, "Fuel", "85%", activeColors),
                      _buildQuickStatTile(Icons.headset_mic_rounded, "Support", "Active", activeColors),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Bottom ride requests section
                  Text(
                    "Nearby Ride Requests",
                    style: TextStyle(
                      color: activeColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dynamic Request Card depending on online status
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: !_isOnline
                        ? _buildOfflineEmptyState(activeColors)
                        : _searchingRidesList.isEmpty
                            ? Container(
                                key: const ValueKey("empty_online"),
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: activeColors.cardBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: activeColors.border, width: 1.1),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const CircularProgressIndicator(strokeWidth: 2.5),
                                      const SizedBox(height: 12),
                                      Text(
                                        "Waiting for nearby requests...",
                                        style: TextStyle(
                                          color: activeColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                key: const ValueKey("requests_online"),
                                children: _searchingRidesList.map((ride) {
                                  final rideId = ride['rideId'] as String? ?? '';
                                  final pickup = ride['pickupAddress'] as String? ?? 'Pickup';
                                  final fare = (ride['estimatedFare'] as num? ?? 68.0).toDouble();
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(context, '/incoming-request', arguments: rideId);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: _buildRealRequestCard(rideId, pickup, fare, activeColors),
                                    ),
                                  );
                                }).toList(),
                              ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // 3. Unified Bottom Navigation Dock (Dashboard active)
          BottomNavBar(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              setState(() {
                _currentNavIndex = index;
              });
              if (index == 2) {
                Navigator.pushNamed(context, '/driver-wallet');
              } else if (index == 1) {
                Navigator.pushNamed(context, '/history');
              } else if (index == 3) {
                Navigator.pushNamed(context, '/profile');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildQuickStatTile(IconData icon, String label, String value, AppModeColors activeColors) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: activeColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeColors.border, width: 1.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: activeColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: activeColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(color: activeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineEmptyState(AppModeColors activeColors) {
    return Container(
      key: const ValueKey("offline"),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: activeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColors.border, width: 1.1),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: activeColors.textSecondary, size: 40),
            const SizedBox(height: 8),
            Text(
              "Go online to view nearby requests",
              style: TextStyle(
                color: activeColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Color scale re-definition helper
const Color _amberDark = Color(0xFFB45309);
