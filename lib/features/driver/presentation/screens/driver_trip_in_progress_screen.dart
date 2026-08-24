// Driver navigation screen showing active passenger ride progress and telemetry updates
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/maps/taxi_town_map_widget.dart';
import '../../../../core/maps/taxi_town_map_container.dart';
import '../../../../core/maps/taxi_town_map_config.dart';
import '../../../../core/maps/taxi_town_map_camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/directions_service.dart';

class DriverTripInProgressScreen extends ConsumerStatefulWidget {
  const DriverTripInProgressScreen({super.key});

  @override
  ConsumerState<DriverTripInProgressScreen> createState() => _DriverTripInProgressScreenState();
}

class _DriverTripInProgressScreenState extends ConsumerState<DriverTripInProgressScreen> {
  GoogleMapController? _mapController;
  String? _rideId;
  Map<String, dynamic>? _rideData;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  List<LatLng> _routePoints = [];
  String? _lastStatus;

  // Locations
  LatLng? _driverPos;
  LatLng? _pickupPos;
  LatLng? _destPos;
  
  int _gpsUpdatesCount = 0;
  LatLng? _lastRouteRecalculationPos;

  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetSize = 0.28;
  double _mapPaddingBottom = 220.0;

  bool _hasFitBounds = false;
  LatLng? _lastCameraFitDriverPos;

  void _fitCamera() async {
    if (_mapController == null || _driverPos == null) return;
    final points = <LatLng>[_driverPos!];
    if (_pickupPos != null) points.add(_pickupPos!);
    if (_destPos != null) points.add(_destPos!);
    if (_routePoints.isNotEmpty) points.addAll(_routePoints);
    await TaxiTownMapCamera.fitPoints(_mapController!, points, padding: 50.0);
  }

  void _maybeFitCamera() {
    if (_driverPos == null || _mapController == null) return;
    bool shouldFit = !_hasFitBounds;
    if (_lastCameraFitDriverPos != null) {
      final distance = Geolocator.distanceBetween(
        _lastCameraFitDriverPos!.latitude,
        _lastCameraFitDriverPos!.longitude,
        _driverPos!.latitude,
        _driverPos!.longitude,
      );
      if (distance > 100.0) {
        shouldFit = true;
      }
    }
    if (shouldFit) {
      _hasFitBounds = true;
      _lastCameraFitDriverPos = _driverPos;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCamera();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      if (!_sheetController.isAttached) return;
      final size = _sheetController.size;
      final screenHeight = MediaQuery.sizeOf(context).height;
      double targetPadding;
      if (size <= 0.35) {
        targetPadding = 0.28 * screenHeight + 24.0;
      } else if (size <= 0.60) {
        targetPadding = 0.52 * screenHeight + 24.0;
      } else {
        targetPadding = 0.75 * screenHeight + 24.0;
      }
      if ((targetPadding - _mapPaddingBottom).abs() > 5.0) {
        if (mounted) {
          setState(() {
            _mapPaddingBottom = targetPadding;
          });
          debugPrint("DRIVER TRIP MAP PADDING SNAPPED TO: $_mapPaddingBottom");
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideId == null) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is String) {
        _rideId = args;
        _listenToRideData();
      } else {
        _rideId = "mock_ride_id";
        _listenToRideData();
      }
    }
  }

  void _listenToRideData() {
    if (_rideId == null) return;
    _rideSubscription?.cancel();
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(_rideId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      if (mounted) {
        final status = data['status'] as String? ?? 'accepted';
        if (_lastStatus != status) {
          _lastStatus = status;
          _gpsUpdatesCount = 0; // Trigger single refit
        }

        setState(() {
          _rideData = data;
          _isLoading = false;
          
          final pLat = data['pickupLatitude'] as num?;
          final pLng = data['pickupLongitude'] as num?;
          if (pLat != null && pLng != null) {
            _pickupPos = LatLng(pLat.toDouble(), pLng.toDouble());
          }

          final dLat = data['destinationLatitude'] as num?;
          final dLng = data['destinationLongitude'] as num?;
          if (dLat != null && dLng != null) {
            _destPos = LatLng(dLat.toDouble(), dLng.toDouble());
          }
        });
        
        _checkAndRecalculateRoute();
      }
    });
  }

  void _checkAndRecalculateRoute() async {
    if (_driverPos == null || _rideData == null) return;
    
    final status = _rideData!['status'] as String? ?? 'accepted';
    
    LatLng start;
    LatLng end;
    final String routeMode;
    if (status == 'accepted') {
      if (_pickupPos == null) return;
      start = _driverPos!;
      end = _pickupPos!;
      routeMode = "Driver -> Pickup";
    } else {
      if (_pickupPos == null || _destPos == null) return;
      start = _pickupPos!;
      end = _destPos!;
      routeMode = "Pickup -> Destination";
    }

    if (_lastRouteRecalculationPos != null) {
      final distanceMoved = Geolocator.distanceBetween(
        _lastRouteRecalculationPos!.latitude,
        _lastRouteRecalculationPos!.longitude,
        _driverPos!.latitude,
        _driverPos!.longitude,
      );
      if (distanceMoved < 30 && _routePoints.isNotEmpty) {
        return; 
      }
    }

    _lastRouteRecalculationPos = _driverPos;

    try {
      final directions = ref.read(directionsServiceProvider);
      final routeInfo = await directions.getDirections(start, end);
      
      if (mounted && routeInfo != null) {
        setState(() {
          _routePoints = routeInfo.points;
        });

        debugPrint("========== DRIVER TRIP MAP ==========");
        debugPrint("Ride ID: $_rideId");
        debugPrint("Driver ID: d_ramesh");
        debugPrint("Ride status: $status");
        debugPrint("Driver location: $_driverPos");
        debugPrint("Pickup location: $_pickupPos");
        debugPrint("Destination location: $_destPos");
        debugPrint("Route mode: $routeMode");
        debugPrint("Route points: ${_routePoints.length}");
        debugPrint("Driver location updates: $_gpsUpdatesCount");
        debugPrint("=====================================");
      }
    } catch (e) {
      debugPrint("Directions query failed: $e");
      if (mounted) {
        setState(() {
          _routePoints = [start, end];
        });
      }
    }
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);
    final liveLocationAsync = ref.watch(liveLocationProvider);

    return Scaffold(
      backgroundColor: activeColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 1. Full-screen map in the background
                Positioned.fill(
                  child: !isGoogleMapsInitialized()
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                "Initializing Maps API...",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : liveLocationAsync.when(
                          data: (position) {
                            final driverLatLng = LatLng(position.latitude, position.longitude);
                            
                            if (_driverPos == null || 
                                _driverPos!.latitude != position.latitude || 
                                _driverPos!.longitude != position.longitude) {
                              _driverPos = driverLatLng;
                              _gpsUpdatesCount++;
                              
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _checkAndRecalculateRoute();
                              });
                            }

                            final Set<Marker> markers = {};

                            markers.add(
                              Marker(
                                markerId: const MarkerId("driver_car"),
                                position: driverLatLng,
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                                infoWindow: const InfoWindow(title: "My Vehicle"),
                              ),
                            );

                            if (_pickupPos != null) {
                              markers.add(
                                Marker(
                                  markerId: const MarkerId("pickup"),
                                  position: _pickupPos!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                  infoWindow: InfoWindow(title: "Pickup: ${_rideData?['pickupAddress'] ?? 'Rider location'}"),
                                ),
                              );
                            }

                            if (_destPos != null) {
                              markers.add(
                                Marker(
                                  markerId: const MarkerId("destination"),
                                  position: _destPos!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                  infoWindow: InfoWindow(title: "Destination: ${_rideData?['destinationAddress'] ?? 'Destination'}"),
                                ),
                              );
                            }

                            _maybeFitCamera();

                            final mapPadding = EdgeInsets.only(
                              bottom: _mapPaddingBottom,
                              top: 120.0,
                              left: 16.0,
                              right: 16.0,
                            );

                            return TaxiTownMap(
                              initialCameraPosition: CameraPosition(
                                target: driverLatLng,
                                zoom: 16.0,
                              ),
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: false,
                              markers: markers,
                              polylines: buildRoutePolylines(_routePoints, activeColors.primary),
                              padding: mapPadding,
                              onMapCreated: (controller) {
                                _mapController = controller;
                                _maybeFitCamera();
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
                                const Text(
                                  "Enable location services to view map updates",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                        ),
                ),

                // 2. Floating status header at the top
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  right: 16,
                  child: _buildFloatingHeader(activeColors),
                ),

                // 3. Draggable scrollable bottom panel
                _buildDraggableTripPanel(context, activeColors),
              ],
            ),
    );
  }

  Widget _buildFloatingHeader(AppModeColors activeColors) {
    final status = _rideData?['status'] as String? ?? 'accepted';
    final statusText = status == 'accepted' 
        ? "Navigating to Pickup" 
        : "Navigating to Destination";
        
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == 'accepted' ? Icons.directions_run_rounded : Icons.local_taxi_rounded,
              color: activeColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                color: activeColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableTripPanel(BuildContext context, AppModeColors activeColors) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.28,
      minChildSize: 0.18,
      maxChildSize: 0.75,
      snap: true,
      builder: (BuildContext context, ScrollController scrollController) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                children: [
                  // Drag Handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Collapsed & Expanded Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ETA / Distance / Fare row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: activeColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: activeColors.border, width: 1.1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildTopStat("ETA", "${(_rideData?['estimatedDurationMinutes'] ?? 10).toStringAsFixed(0)} mins", activeColors),
                                _buildVerticalDivider(activeColors),
                                _buildTopStat("DISTANCE", "${(_rideData?['distanceKm'] ?? 4.2).toStringAsFixed(1)} km", activeColors),
                                _buildVerticalDivider(activeColors),
                                _buildTopStat("FARE", "₹${(_rideData?['estimatedFare'] ?? 68.0).toStringAsFixed(0)}", activeColors),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Rider Card Info
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: activeColors.cardBackground,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: activeColors.border, width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: activeColors.primary.withOpacity(0.12),
                                      child: Icon(Icons.person_rounded, color: activeColors.primary, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Rider: ${_rideData?['riderName'] ?? 'Priya'}",
                                            style: TextStyle(
                                              color: activeColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Destination: ${_rideData?['destinationAddress'] ?? 'Anantapur Bus Stand'}",
                                            style: TextStyle(
                                              color: activeColors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    _buildRoundAction(Icons.phone_rounded, "Call Rider", () {
                                      context.showSnackBar("Calling ${_rideData?['riderName'] ?? 'Priya'}...");
                                    }, activeColors),
                                    _buildRoundAction(Icons.share_rounded, "Share Trip", () {
                                      context.showSnackBar("Trip link copied successfully!");
                                    }, activeColors),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                ElevatedButton(
                                  onPressed: () async {
                                    if (_rideId == null) return;
                                    
                                    if (FirebaseService.isFirebaseAvailable) {
                                      try {
                                        final rideRef = FirebaseFirestore.instance.collection('rides').doc(_rideId);
                                        final driverRef = FirebaseFirestore.instance.collection('drivers').doc("d_ramesh");
                                        
                                        await FirebaseFirestore.instance.runTransaction((transaction) async {
                                          transaction.update(rideRef, {
                                            'status': 'completed',
                                            'completedAt': FieldValue.serverTimestamp(),
                                          });
                                          transaction.update(driverRef, {
                                            'isAvailable': true,
                                          });
                                        });
                                      } catch (e) {
                                        debugPrint("End trip transaction failed: $e");
                                        await FirebaseService.completeRide(_rideId!, "d_ramesh");
                                      }
                                    } else {
                                      await FirebaseService.completeRide(_rideId!, "d_ramesh");
                                    }

                                    ref.read(activeDriverRideIdProvider.notifier).state = null;
                                    Navigator.pushNamed(context, '/driver-trip-completed');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    "End Trip",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopStat(String label, String value, AppModeColors activeColors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: activeColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(AppModeColors activeColors) {
    return Container(
      width: 1.2,
      height: 24,
      color: activeColors.border,
    );
  }

  Widget _buildRoundAction(IconData icon, String label, VoidCallback onTap, AppModeColors activeColors) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: activeColors.elevatedCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: activeColors.border, width: 1.1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: activeColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
