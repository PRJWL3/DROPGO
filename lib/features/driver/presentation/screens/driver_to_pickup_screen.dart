import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/maps/taxi_town_map_widget.dart';
import '../../../../core/maps/taxi_town_map_config.dart';
import '../../../../core/maps/taxi_town_map_camera.dart';

class DriverToPickupScreen extends ConsumerStatefulWidget {
  const DriverToPickupScreen({super.key});

  @override
  ConsumerState<DriverToPickupScreen> createState() => _DriverToPickupScreenState();
}

class _DriverToPickupScreenState extends ConsumerState<DriverToPickupScreen> {
  GoogleMapController? _mapController;
  String? _rideId;
  Map<String, dynamic>? _rideData;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  List<LatLng> _routePoints = [];

  // Locations
  LatLng? _driverPos;
  LatLng? _pickupPos;
  
  int _gpsUpdatesCount = 0;
  LatLng? _lastRouteRecalculationPos;

  bool _hasFitBounds = false;
  LatLng? _lastCameraFitDriverPos;

  void _fitCamera() async {
    if (_mapController == null || _driverPos == null) return;
    final points = <LatLng>[_driverPos!];
    if (_pickupPos != null) points.add(_pickupPos!);
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
        setState(() {
          _rideData = data;
          _isLoading = false;
          
          final pLat = data['pickupLatitude'] as num?;
          final pLng = data['pickupLongitude'] as num?;
          if (pLat != null && pLng != null) {
            _pickupPos = LatLng(pLat.toDouble(), pLng.toDouble());
          }
        });
        
        _checkAndRecalculateRoute();
      }
    });
  }

  void _checkAndRecalculateRoute() async {
    if (_driverPos == null || _pickupPos == null) return;
    
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
      final routeInfo = await directions.getDirections(_driverPos!, _pickupPos!);
      
      if (mounted && routeInfo != null) {
        setState(() {
          _routePoints = routeInfo.points;
        });
      }
    } catch (e) {
      debugPrint("Directions query failed: $e");
      if (mounted) {
        setState(() {
          _routePoints = [_driverPos!, _pickupPos!];
        });
      }
    }
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _mapController?.dispose();
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
                // 1. Full-screen map background
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

                            _maybeFitCamera();

                            final mapPadding = EdgeInsets.only(
                              bottom: 280.0,
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

                // 2. Floating Top Overlay Card (ETA, Distance)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  right: 16,
                  child: liveLocationAsync.when(
                    data: (position) {
                      double distMeters = 1200;
                      if (_pickupPos != null) {
                        distMeters = Geolocator.distanceBetween(
                          position.latitude,
                          position.longitude,
                          _pickupPos!.latitude,
                          _pickupPos!.longitude,
                        );
                      }
                      
                      final isClose = distMeters <= 200;
                      final distanceText = distMeters >= 1000 
                          ? "${(distMeters / 1000).toStringAsFixed(1)} km to pickup" 
                          : "${distMeters.toStringAsFixed(0)} m to pickup";
                          
                      final etaText = "ETA ${(distMeters / 300).toStringAsFixed(0)} mins"; // rough estimate

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: activeColors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: activeColors.border, width: 1.1),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isClose ? "Arrived at pickup" : etaText,
                                  style: TextStyle(
                                    color: activeColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isClose ? "You've arrived" : distanceText,
                                  style: TextStyle(
                                    color: activeColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: activeColors.primary.withOpacity(0.12),
                                  child: Icon(Icons.person_rounded, color: activeColors.primary, size: 14),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Rider: ${_rideData?['riderName'] ?? 'Priya'}",
                                  style: TextStyle(
                                    color: activeColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    error: (err, stack) => const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                  ),
                ),

                // 3. Floating Bottom Sheet panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColors.cardBackground,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(top: BorderSide(color: activeColors.border, width: 1.2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.paddingOf(context).bottom + 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "PICKUP ADDRESS",
                          style: TextStyle(
                            color: activeColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: activeColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _rideData?['pickupAddress'] ?? "Ramapuram Market, Bengaluru",
                                style: TextStyle(
                                  color: activeColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Actions row (Call, Message)
                        Row(
                          children: [
                            _buildRoundAction(Icons.phone_rounded, "Call Rider", () {
                              context.showSnackBar("Calling ${_rideData?['riderName'] ?? 'Priya'}...");
                            }, activeColors),
                            _buildRoundAction(Icons.forum_rounded, "Message", () {
                              context.showSnackBar("Opening Chat with ${_rideData?['riderName'] ?? 'Priya'}...");
                            }, activeColors),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Primary Arrived button
                        ElevatedButton(
                          onPressed: () async {
                            if (_rideId == null) return;
                            try {
                              // Update ride status to driver_arrived
                              final rideRef = FirebaseFirestore.instance.collection('rides').doc(_rideId);
                              await rideRef.update({'status': 'driver_arrived'});
                            } catch (e) {
                              debugPrint("Update status to driver_arrived failed: $e");
                            }
                            
                            if (mounted) {
                              Navigator.pushReplacementNamed(context, '/driver-arrived', arguments: _rideId);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "I've arrived",
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
                ),

                // 4. Floating back button
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: activeColors.cardBackground,
                      shape: BoxShape.circle,
                      border: Border.all(color: activeColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: activeColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
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
          child: Column(
            children: [
              Icon(icon, color: activeColors.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColors.textPrimary,
                  fontSize: 11,
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
