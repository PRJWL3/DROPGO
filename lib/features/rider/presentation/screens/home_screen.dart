// Premium home screen displaying the main passenger ride booking dashboard
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/location_card.dart';
import '../widgets/quick_place_card.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/maps/taxi_town_map_widget.dart';
import '../../../../core/maps/taxi_town_map_camera.dart';
import '../../../../core/providers/location_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/constants/map_style.dart';
import '../../../../core/utils/marker_utils.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../providers/driver_location_provider.dart';
import '../../../driver/presentation/screens/driver_home_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;
  GoogleMapController? _mapController;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;
  BitmapDescriptor? _bikeDriverIcon;
  bool _isDisposed = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  final Map<String, Marker> _driverMarkers = {};
  final Map<String, LatLng> _driverPositions = {};
  bool _hasFitInitialDrivers = false;

  bool _hasInitializedLocation = false;
  double _mapPaddingBottom = 220.0;

  void _onSheetSizeChanged() {
    if (_isDisposed || !mounted) return;
    if (_sheetController.isAttached) {
      final size = _sheetController.size;
      final screenHeight = MediaQuery.sizeOf(context).height;
      double targetPadding;
      if (size <= 0.35) {
        targetPadding = 0.32 * screenHeight + 16.0;
      } else if (size <= 0.60) {
        targetPadding = 0.52 * screenHeight + 16.0;
      } else {
        targetPadding = 0.92 * screenHeight + 16.0;
      }
      
      if ((targetPadding - _mapPaddingBottom).abs() > 5.0) {
        setState(() {
          _mapPaddingBottom = targetPadding;
        });
        debugPrint("MAP PADDING SNAPPED TO: $_mapPaddingBottom");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
    // Load custom pickup marker icon
    MarkerUtils.getPickupMarker().then((icon) {
      if (mounted) {
        setState(() {
          _pickupIcon = icon;
        });
      }
    }).catchError((e) {
      debugPrint("Failed to load custom pickup icon: $e");
    });
    MarkerUtils.getBikeDriverMarker().then((icon) {
      if (mounted) {
        setState(() {
          _bikeDriverIcon = icon;
        });
      }
    }).catchError((e) {
      debugPrint("Failed to load custom bike icon: $e");
    });
    MarkerUtils.getDestinationMarker().then((icon) {
      if (mounted) {
        setState(() {
          _destIcon = icon;
        });
      }
    }).catchError((e) {
      debugPrint("Failed to load custom destination icon: $e");
    });
    // Ask location permission and set pickup on first open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final service = ref.read(locationServiceProvider);
        final hasPermission = await service.requestPermission();
        if (hasPermission) {
          final position = await service.getCurrentLocation();
          final address = await service.getAddressFromLatLng(position.latitude, position.longitude);
          final pickup = LocationPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            name: address,
          );
          ref.read(rideBookingNotifierProvider.notifier).selectPickup(pickup);
        }
      } catch (e) {
        debugPrint("Location permission check failed or startup fetch error: $e");
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapController = null;
    _sheetController.dispose();
    super.dispose();
  }

  void _recenterMap(double lat, double lng) async {
    if (_isDisposed || !mounted || _mapController == null) return;
    await TaxiTownMapCamera.centerOnLocation(_mapController!, LatLng(lat, lng), zoom: 16.0);
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    return TaxiTownMapCamera.getBounds(points);
  }

  void _fitRoute(List<LatLng> points) async {
    if (_isDisposed || !mounted || _mapController == null || points.isEmpty) return;
    await TaxiTownMapCamera.fitPoints(_mapController!, points, padding: 80.0);
  }

  void _animateMarker(String driverId, LatLng from, LatLng to) {
    const steps = 15;
    const duration = Duration(milliseconds: 1000);
    final delay = Duration(milliseconds: (duration.inMilliseconds / steps).round());
    int currentStep = 0;

    Timer.periodic(delay, (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double fraction = currentStep / steps;
      final double lat = from.latitude + (to.latitude - from.latitude) * fraction;
      final double lng = from.longitude + (to.longitude - from.longitude) * fraction;

      if (mounted) {
        setState(() {
          final oldMarker = _driverMarkers[driverId];
          if (oldMarker != null) {
            _driverMarkers[driverId] = oldMarker.copyWith(
              positionParam: LatLng(lat, lng),
            );
          }
        });
      }

      if (currentStep >= steps) {
        timer.cancel();
      }
    });
  }

  void _syncDriverMarkers(List<Map<String, dynamic>> drivers) {
    if (!mounted) return;

    final bookingState = ref.read(rideBookingNotifierProvider);
    LatLng? pickupLatLng;
    if (bookingState.pickup != null) {
      pickupLatLng = LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude);
    } else {
      final locVal = ref.read(currentLocationProvider).value;
      if (locVal != null) {
        pickupLatLng = LatLng(locVal.latitude, locVal.longitude);
      }
    }

    // Filter vehicleType to match "bike" and within 5.0 km radius
    final eligibleDrivers = drivers.where((d) {
      if (d['vehicleType'] != 'bike') return false;
      final lat = (d['currentLatitude'] as num?)?.toDouble();
      final lng = (d['currentLongitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;
      
      if (pickupLatLng != null) {
        final distanceMeters = Geolocator.distanceBetween(
          pickupLatLng.latitude,
          pickupLatLng.longitude,
          lat,
          lng,
        );
        final distanceKm = distanceMeters / 1000.0;
        return distanceKm <= 5.0; // 5 km radius limit
      }
      return true; // if no user location, show all online bikes
    }).toList();

    // Debug logs when actual data changes (Requirement 13)
    debugPrint("DRIVER DATA UPDATED");
    debugPrint("Eligible drivers: ${eligibleDrivers.length}");

    final currentIds = eligibleDrivers.map((d) => d['driverId'] as String).toSet();

    // Remove offline/unavailable driver markers
    final removedIds = _driverMarkers.keys.where((id) => !currentIds.contains(id)).toList();
    for (var id in removedIds) {
      _driverMarkers.remove(id);
      _driverPositions.remove(id);
      debugPrint("REAL DRIVER REMOVED\nDriver ID: $id");
    }

    for (var driver in eligibleDrivers) {
      final driverId = driver['driverId'] as String;
      final lat = (driver['currentLatitude'] as num).toDouble();
      final lng = (driver['currentLongitude'] as num).toDouble();
      final newLatLng = LatLng(lat, lng);

      // Distance calculation
      double distanceKm = 1.2;
      if (pickupLatLng != null) {
        final distanceMeters = Geolocator.distanceBetween(
          pickupLatLng.latitude,
          pickupLatLng.longitude,
          lat,
          lng,
        );
        distanceKm = distanceMeters / 1000.0;
      }
      final distanceStr = "${distanceKm.toStringAsFixed(1)} km";

      if (!_driverMarkers.containsKey(driverId)) {
        // Step 9: Reappear / Add driver
        _driverMarkers[driverId] = Marker(
          markerId: MarkerId(driverId),
          position: newLatLng,
          icon: _bikeDriverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: "Vehicle: Bike",
            snippet: "Approximate distance: $distanceStr • Available",
          ),
        );
        _driverPositions[driverId] = newLatLng;
        
      } else {
        // Step 7: Animate movement locally
        final oldLatLng = _driverPositions[driverId];
        if (oldLatLng != null && (oldLatLng.latitude != lat || oldLatLng.longitude != lng)) {
          _animateMarker(driverId, oldLatLng, newLatLng);
          _driverPositions[driverId] = newLatLng;

          // Debug logs (Requirement 13)
          debugPrint("DRIVER LOCATION UPDATED");
          debugPrint("Driver ID: $driverId");
        }
      }
    }

    // Step 10: Fit bounds ONLY once when initial driver markers are first loaded
    if (!_hasFitInitialDrivers && eligibleDrivers.isNotEmpty && _mapController != null) {
      _hasFitInitialDrivers = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitInitialCameraBounds(eligibleDrivers);
      });
    }

    setState(() {});
  }

  void _fitInitialCameraBounds(List<Map<String, dynamic>> drivers) {
    if (_mapController == null || drivers.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (var driver in drivers) {
      final lat = (driver['currentLatitude'] as num).toDouble();
      final lng = (driver['currentLongitude'] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bookingState = ref.read(rideBookingNotifierProvider);
    if (bookingState.pickup != null) {
      final pLat = bookingState.pickup!.latitude;
      final pLng = bookingState.pickup!.longitude;
      if (pLat < minLat) minLat = pLat;
      if (pLat > maxLat) maxLat = pLat;
      if (pLng < minLng) minLng = pLng;
      if (pLng > maxLng) maxLng = pLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("RIDER HOME BUILD");
    final mode = ref.watch(appModeProvider);
    final activeColors = ref.watch(appModeColorsProvider);
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final isRouteSelected = bookingState.pickup != null && bookingState.destination != null;

    // Centering camera on real GPS location on first load
    ref.listen<AsyncValue<Position>>(currentLocationProvider, (previous, next) {
      next.whenData((pos) {
        if (!_hasInitializedLocation && _mapController != null) {
          _hasInitializedLocation = true;
          final target = bookingState.pickup != null
              ? LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude)
              : LatLng(pos.latitude, pos.longitude);
          TaxiTownMapCamera.centerOnLocation(_mapController!, target, zoom: 16.0);
        }
      });
    });

    // Listen to online drivers stream for real-time Firestore sync
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(onlineDriversProvider, (previous, next) {
      next.whenData((drivers) {
        _syncDriverMarkers(drivers);
      });
    });

    // riverpod listener to animate the sheet smoothly when route is selected
    ref.listen<RideBookingState>(rideBookingNotifierProvider, (previous, next) {
      final wasRouteSelected = previous?.pickup != null && previous?.destination != null;
      final isNowSelected = next.pickup != null && next.destination != null;
      if (isNowSelected && !wasRouteSelected) {
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.52,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else if (!isNowSelected && wasRouteSelected) {
        if (_sheetController.isAttached) {
          _sheetController.animateTo(
            0.32,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: mode == AppMode.rider
          ? Scaffold(
              key: const ValueKey("rider_home"),
              backgroundColor: activeColors.background,
              body: Stack(
                children: [
                  // 1. Full-screen map in the background
                  Positioned.fill(
                    child: _buildFullScreenMap(context, activeColors),
                  ),

                  // 2. Floating AppTopBar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppTopBar(
                      onMenuTap: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                      onNotificationTap: () {
                        context.showSnackBar("You have 3 new notifications");
                      },
                      notificationCount: 3,
                    ),
                  ),

                  // 3. Floating Recenter FAB
                  Positioned(
                    top: 90,
                    right: 16,
                    child: FloatingActionButton.small(
                      backgroundColor: activeColors.primary,
                      elevation: 4,
                      hoverElevation: 8,
                      hoverColor: activeColors.primary.withOpacity(0.85),
                      onPressed: () {
                        if (bookingState.pickup != null) {
                          _recenterMap(bookingState.pickup!.latitude, bookingState.pickup!.longitude);
                        } else {
                          ref.read(currentLocationProvider).whenData((pos) {
                            _recenterMap(pos.latitude, pos.longitude);
                          });
                        }
                      },
                      child: const Icon(Icons.my_location_rounded, color: Colors.white),
                    ),
                  ),

                  // 3.1. Temporary Debug Button
                  Positioned(
                    top: 90,
                    left: 16,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565FF),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        "TEST FIRESTORE RIDE",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                      ),
                      onPressed: () async {
                        final timestamp = DateTime.now().millisecondsSinceEpoch;
                        final testRideId = "test_$timestamp";
                        final expiresAt = DateTime.now().add(const Duration(seconds: 60));
                        
                        debugPrint("========== TEST FIRESTORE WRITE START ==========");
                        debugPrint("Writing test ride to Firestore...");
                        debugPrint("Firestore path: /rides/$testRideId");

                        if (FirebaseService.isFirebaseAvailable) {
                          try {
                            await FirebaseFirestore.instance.collection('rides').doc(testRideId).set({
                              'rideId': testRideId,
                              'status': 'searching',
                              'vehicleType': 'bike',
                              'createdAt': FieldValue.serverTimestamp(),
                              'expiresAt': Timestamp.fromDate(expiresAt),
                            }).timeout(const Duration(seconds: 15));
                            
                            debugPrint("Test ride successfully written to Firestore: $testRideId");
                          } catch (e) {
                            debugPrint("Test ride write failed: $e");
                          }
                        } else {
                          debugPrint("Test ride skipped: Firebase is not available.");
                        }
                      },
                    ),
                  ),

                  // 3.2. Nearby Drivers Floating Indicator
                  Positioned(
                    bottom: (MediaQuery.sizeOf(context).height * 0.32) + 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: FirebaseService.isFirebaseAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              !FirebaseService.isFirebaseAvailable
                                  ? "Firebase disconnected"
                                  : (_driverMarkers.isEmpty
                                      ? "No nearby drivers"
                                      : "${_driverMarkers.length} ${_driverMarkers.length == 1 ? 'driver' : 'drivers'} nearby"),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Draggable Scrollable Ride Panel
                  _buildDraggableRidePanel(context, activeColors),
                ],
              ),
              bottomNavigationBar: isRouteSelected
                  ? null
                  : BottomNavBar(
                      currentIndex: _currentNavIndex,
                      onTap: (index) {
                        setState(() {
                          _currentNavIndex = index;
                        });
                        if (index == 2) {
                          Navigator.pushNamed(context, '/wallet');
                        } else if (index == 1) {
                          Navigator.pushNamed(context, '/history');
                        } else if (index == 3) {
                          Navigator.pushNamed(context, '/profile');
                        }
                      },
                    ),
            )
          : const DriverHomeScreen(key: ValueKey("driver_home")),
    );
  }

  Widget _buildFullScreenMap(BuildContext context, AppModeColors activeColors) {
    if (!isGoogleMapsInitialized()) {
      return Container(
        color: activeColors.cardBackground,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Initializing Maps API...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final bookingState = ref.watch(rideBookingNotifierProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    Set<Marker> markers = {};
    Set<Polyline> polylines = {};
    LatLng initialTarget = const LatLng(12.9716, 77.5946); // default Bangalore
    double initialZoom = 15.0;

    // Determine pickup position
    LatLng? pickupLatLng;
    if (bookingState.pickup != null) {
      pickupLatLng = LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude);
    } else {
      locationAsync.whenData((pos) {
        pickupLatLng = LatLng(pos.latitude, pos.longitude);
      });
    }

    if (pickupLatLng != null) {
      initialTarget = pickupLatLng!;
      markers.add(
        Marker(
          markerId: const MarkerId("pickup"),
          position: pickupLatLng!,
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: bookingState.pickup != null ? "Pickup: ${bookingState.pickup!.name}" : "My Position"),
        ),
      );
    }

    // Determine destination position
    LatLng? destLatLng;
    if (bookingState.destination != null) {
      destLatLng = LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude);
      initialTarget = destLatLng!;
      markers.add(
        Marker(
          markerId: const MarkerId("dest"),
          position: destLatLng!,
          icon: _destIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: "Destination: ${bookingState.destination!.name}"),
        ),
      );
    }

    // Load route info if both are available
    RouteInfo? routeInfo;
    if (pickupLatLng != null && destLatLng != null) {
      final routeArg = (origin: pickupLatLng!, destination: destLatLng!);
      ref.watch(routeInfoProvider(routeArg)).whenData((info) {
        routeInfo = info;
      });
    }

    if (routeInfo != null) {
      polylines = {
        Polyline(
          polylineId: const PolylineId("route_outline"),
          points: routeInfo!.points,
          color: Colors.white,
          width: 10,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
        Polyline(
          polylineId: const PolylineId("route_fill"),
          points: routeInfo!.points,
          color: const Color(0xFF1565FF),
          width: 6,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      };

      if (_mapController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitRoute(routeInfo!.points);
        });
      }
    }
    // Add nearby online driver markers
    markers.addAll(_driverMarkers.values);

    return TaxiTownMap(
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: initialZoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      padding: EdgeInsets.only(bottom: _mapPaddingBottom, top: 100.0, left: 16.0, right: 16.0),
      markers: markers,
      polylines: polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        if (!_hasInitializedLocation) {
          final loc = ref.read(currentLocationProvider).value;
          if (loc != null) {
            _hasInitializedLocation = true;
            final target = bookingState.pickup != null
                ? LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude)
                : LatLng(loc.latitude, loc.longitude);
            TaxiTownMapCamera.centerOnLocation(controller, target, zoom: 16.0);
          }
        }
        if (routeInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitRoute(routeInfo!.points);
          });
        }
      },
    );
  }

  Widget _buildDraggableRidePanel(BuildContext context, AppModeColors activeColors) {
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final isRouteSelected = bookingState.pickup != null && bookingState.destination != null;

    RouteInfo? routeInfo;
    if (isRouteSelected) {
      final routeArg = (
        origin: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
        destination: LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
      );
      ref.watch(routeInfoProvider(routeArg)).whenData((info) {
        routeInfo = info;
      });
    }

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.32,
      minChildSize: 0.18,
      maxChildSize: 0.92,
      snap: true,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalPadding),
                  children: [
                    // Destination Search Field / Selector Button
                    GestureDetector(
                      onTap: () {
                        ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                        Navigator.pushNamed(context, '/search');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // Light grey background
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Color(0xFF1565FF), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bookingState.destination?.name ?? "Where do you want to go?",
                                style: TextStyle(
                                  color: bookingState.destination != null ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Now dropdown button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, color: Color(0xFF0F172A), size: 14),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "Now",
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // If route is active, show the ride details card
                    if (isRouteSelected && routeInfo != null) ...[
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade100, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text("DISTANCE", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${routeInfo!.distanceKm.toStringAsFixed(1)} km",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 28, color: Colors.grey.shade200),
                                  Column(
                                    children: [
                                      const Text("ETA", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${routeInfo!.durationMin.toStringAsFixed(0)} mins",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 28, color: Colors.grey.shade200),
                                  Column(
                                    children: [
                                      const Text("EST. FARE", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "₹${routeInfo!.estimatedFare.toStringAsFixed(0)}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                text: "Confirm Ride Details",
                                onPressed: () {
                                  Navigator.pushNamed(context, '/ride-options');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Saved Places",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                            Navigator.pushNamed(context, '/search');
                          },
                          child: const Text(
                            "See all",
                            style: TextStyle(
                              color: Color(0xFF1565FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontally scrollable list of Saved Places cards
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        children: [
                          _buildSavedPlaceCard(
                            icon: Icons.home_rounded,
                            label: "Home",
                            distance: "12.4 km",
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildSavedPlaceCard(
                            icon: Icons.work_rounded,
                            label: "Work",
                            distance: "8.7 km",
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildSavedPlaceCard(
                            icon: Icons.storefront_rounded,
                            label: "Market",
                            distance: "3.2 km",
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildSavedPlaceCard(
                            icon: Icons.add_box_rounded,
                            label: "Hospital",
                            distance: "5.6 km",
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
                          ),
                          const SizedBox(width: 12),
                          _buildSavedPlaceCard(
                            icon: Icons.directions_bus_rounded,
                            label: "Bus Stand",
                            distance: "4.3 km",
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // DropGo safety banner card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD1E3FF), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1565FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Wherever you go, DropGo gets you there.",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Safe rides • Local drivers • Simple fares",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.sports_motorsports_rounded,
                            color: Color(0xFF1565FF),
                            size: 32,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedPlaceCard({
    required IconData icon,
    required String label,
    required String distance,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1565FF), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              distance,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}

// Sub-widget: Vector drawn car city illustration
class DashboardIllustration extends StatelessWidget {
  const DashboardIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CitySkylinePainter(),
            ),
          ),
          Positioned(
            top: 10,
            right: 25,
            width: 48,
            height: 60,
            child: CustomPaint(
              painter: BluePinPainter(),
            ),
          ),
          Positioned(
            bottom: 5,
            right: -10,
            width: 150,
            height: 70,
            child: CustomPaint(
              painter: CarPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class CitySkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final buildings = [
      Rect.fromLTWH(10, size.height - 70, 16, 70),
      Rect.fromLTWH(30, size.height - 95, 20, 95),
      Rect.fromLTWH(54, size.height - 80, 18, 80),
      Rect.fromLTWH(76, size.height - 110, 24, 110),
      Rect.fromLTWH(104, size.height - 90, 22, 90),
      Rect.fromLTWH(130, size.height - 75, 16, 75),
      Rect.fromLTWH(150, size.height - 60, 20, 60),
    ];

    for (var rect in buildings) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BluePinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = size.width / 2;

    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -0.2,
      3.5,
      false,
    );
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final cutoutPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.4, cutoutPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromLTRB(w * 0.05, h * 0.85, w * 0.95, h * 0.98),
      shadowPaint,
    );

    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.15, h * 0.75);
    bodyPath.lineTo(w * 0.10, h * 0.70);
    bodyPath.quadraticBezierTo(w * 0.08, h * 0.58, w * 0.12, h * 0.52);
    bodyPath.lineTo(w * 0.22, h * 0.38);
    bodyPath.quadraticBezierTo(w * 0.45, h * 0.33, w * 0.65, h * 0.35);
    bodyPath.lineTo(w * 0.80, h * 0.52);
    bodyPath.quadraticBezierTo(w * 0.88, h * 0.54, w * 0.94, h * 0.62);
    bodyPath.lineTo(w * 0.98, h * 0.70);
    bodyPath.lineTo(w * 0.96, h * 0.78);
    bodyPath.lineTo(w * 0.82, h * 0.78);
    bodyPath.arcTo(
      Rect.fromCircle(center: Offset(w * 0.74, h * 0.76), radius: w * 0.085),
      3.14,
      -3.14,
      false,
    );
    bodyPath.lineTo(w * 0.40, h * 0.78);
    bodyPath.arcTo(
      Rect.fromCircle(center: Offset(w * 0.30, h * 0.76), radius: w * 0.085),
      3.14,
      -3.14,
      false,
    );
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, strokePaint);

    final windowPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.fill;
    final windowPath = Path();
    windowPath.moveTo(w * 0.28, h * 0.42);
    windowPath.lineTo(w * 0.48, h * 0.40);
    windowPath.lineTo(w * 0.48, h * 0.52);
    windowPath.lineTo(w * 0.28, h * 0.52);
    windowPath.close();

    final frontWindowPath = Path();
    frontWindowPath.moveTo(w * 0.51, h * 0.40);
    frontWindowPath.lineTo(w * 0.68, h * 0.40);
    frontWindowPath.lineTo(w * 0.75, h * 0.52);
    frontWindowPath.lineTo(w * 0.51, h * 0.52);
    frontWindowPath.close();

    canvas.drawPath(windowPath, windowPaint);
    canvas.drawPath(frontWindowPath, windowPaint);

    final tirePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    final hubPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    final rearWheel = Offset(w * 0.30, h * 0.76);
    final frontWheel = Offset(w * 0.74, h * 0.76);
    final wheelRadius = w * 0.08;

    canvas.drawCircle(rearWheel, wheelRadius, tirePaint);
    canvas.drawCircle(rearWheel, wheelRadius * 0.55, hubPaint);

    canvas.drawCircle(frontWheel, wheelRadius, tirePaint);
    canvas.drawCircle(frontWheel, wheelRadius * 0.55, hubPaint);

    final lightPaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.93, h * 0.63, w * 0.04, h * 0.04),
        const Radius.circular(2),
      ),
      lightPaint,
    );

    final tailPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.58, w * 0.03, h * 0.05),
        const Radius.circular(2),
      ),
      tailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sub-widget: Eco Promo banner with blue tree vector
class EcoPromoCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const EcoPromoCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF), // Light blue background container
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 6,
            bottom: 6,
            width: 90,
            child: CustomPaint(
              painter: BlueTreePainter(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 110, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    final isActive = index == 0;
                    return Container(
                      width: isActive ? 12 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BlueTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final trunkPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;
    final trunkPath = Path();
    trunkPath.moveTo(w * 0.46, h * 0.90);
    trunkPath.lineTo(w * 0.48, h * 0.55);
    trunkPath.lineTo(w * 0.52, h * 0.55);
    trunkPath.lineTo(w * 0.54, h * 0.90);
    trunkPath.close();
    canvas.drawPath(trunkPath, trunkPaint);

    final branchPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.49, h * 0.65), Offset(w * 0.38, h * 0.52), branchPaint);
    canvas.drawLine(Offset(w * 0.51, h * 0.60), Offset(w * 0.62, h * 0.48), branchPaint);

    final foliageColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.lightBlue,
    ];

    void drawLeafCluster(Offset center, double radius, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
    }

    drawLeafCluster(Offset(w * 0.35, h * 0.45), w * 0.22, foliageColors[0]);
    drawLeafCluster(Offset(w * 0.65, h * 0.45), w * 0.22, foliageColors[0]);
    drawLeafCluster(Offset(w * 0.50, h * 0.30), w * 0.24, foliageColors[0]);

    drawLeafCluster(Offset(w * 0.38, h * 0.40), w * 0.18, foliageColors[1]);
    drawLeafCluster(Offset(w * 0.62, h * 0.40), w * 0.18, foliageColors[1]);
    drawLeafCluster(Offset(w * 0.50, h * 0.34), w * 0.20, foliageColors[1]);

    drawLeafCluster(Offset(w * 0.45, h * 0.36), w * 0.14, foliageColors[2]);
    drawLeafCluster(Offset(w * 0.55, h * 0.36), w * 0.14, foliageColors[2]);
    drawLeafCluster(Offset(w * 0.50, h * 0.26), w * 0.12, foliageColors[2]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
