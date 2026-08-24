// Screen displaying available fare estimates and category selections matching reference image layout
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/maps/taxi_town_map_widget.dart';
import '../../../../core/maps/taxi_town_map_config.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/providers/location_provider.dart';
import '../../providers/ride_provider.dart';
import '../../../../core/constants/map_style.dart';
import '../../../../core/utils/marker_utils.dart';
import '../widgets/ride_option_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/providers/app_mode_provider.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../providers/driver_location_provider.dart';
import '../../../../core/services/directions_service.dart';

import '../../../../core/maps/taxi_town_map_camera.dart';

class RideOptionsScreen extends ConsumerStatefulWidget {
  const RideOptionsScreen({super.key});

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  String _selectedClass = "Bike";
  double? _lastEstimatedFare;
  GoogleMapController? _mapController;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;
  BitmapDescriptor? _bikeDriverIcon;
  bool _isDisposed = false;

  final Map<String, Marker> _driverMarkers = {};
  final Map<String, LatLng> _driverPositions = {};
  bool _hasFitInitialDrivers = false;

  @override
  void initState() {
    super.initState();
    MarkerUtils.getPickupMarker().then((icon) {
      if (mounted) {
        setState(() {
          _pickupIcon = icon;
        });
      }
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
          _destinationIcon = icon;
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapController = null;
    super.dispose();
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    return TaxiTownMapCamera.getBounds(points);
  }

  void _fitRoute(List<LatLng> points) async {
    if (_isDisposed || !mounted || _mapController == null || points.isEmpty) return;
    await TaxiTownMapCamera.fitPoints(_mapController!, points, padding: 80);
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

    // Filter vehicleType to match "bike"
    final eligibleDrivers = drivers.where((d) => d['vehicleType'] == 'bike').toList();

    final currentIds = eligibleDrivers.map((d) => d['driverId'] as String).toSet();

    // Remove offline/unavailable driver markers
    final removedIds = _driverMarkers.keys.where((id) => !currentIds.contains(id)).toList();
    for (var id in removedIds) {
      _driverMarkers.remove(id);
      _driverPositions.remove(id);
      debugPrint("DRIVER REMOVED: $id");
    }

    final bookingState = ref.read(rideBookingNotifierProvider);
    LatLng? pickupLatLng;
    if (bookingState.pickup != null) {
      pickupLatLng = LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude);
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
        debugPrint("DRIVER ADDED: $driverId");
      } else {
        // Step 7: Animate movement locally
        final oldLatLng = _driverPositions[driverId];
        if (oldLatLng != null && (oldLatLng.latitude != lat || oldLatLng.longitude != lng)) {
          _animateMarker(driverId, oldLatLng, newLatLng);
          _driverPositions[driverId] = newLatLng;
          debugPrint("DRIVER MOVED: $driverId");
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
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final bookingNotifier = ref.read(rideBookingNotifierProvider.notifier);
    final activeColors = ref.watch(appModeColorsProvider);

    if (bookingState.pickup == null || bookingState.destination == null) {
      return Scaffold(
        body: const Center(child: Text("Missing pickup or destination")),
      );
    }

    final routeArg = (
      origin: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
      destination: LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
    );

    final routeInfoAsync = ref.watch(routeInfoProvider(routeArg));

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(onlineDriversProvider, (previous, next) {
      next.whenData((drivers) {
        _syncDriverMarkers(drivers);
      });
    });

    ref.listen<String?>(rideErrorProvider, (previous, next) {
      if (next != null && mounted) {
        context.showSnackBar(next, backgroundColor: Colors.red);
        ref.read(rideErrorProvider.notifier).state = null;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Ride Options",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Full-screen Map preview background
          Positioned.fill(
            child: _buildMapBackground(context, bookingState, routeInfoAsync),
          ),

          // 2. Draggable scrollable ride options sheet
          _buildDraggableOptionsPanel(context, activeColors, routeInfoAsync, bookingNotifier),
        ],
      ),
    );
  }

  Widget _buildMapBackground(BuildContext context, RideBookingState bookingState, AsyncValue<RouteInfo?> routeInfoAsync) {
    if (!isGoogleMapsInitialized()) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text("Initializing Maps API...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      );
    }

    return routeInfoAsync.when(
      data: (routeInfo) {
        if (routeInfo == null) {
          return const Center(child: Text("Route info not available"));
        }

        if (_mapController != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitRoute(routeInfo.points);
          });
        }

        _lastEstimatedFare = routeInfo.estimatedFare;

        final mapPadding = EdgeInsets.only(
          bottom: MediaQuery.sizeOf(context).height * 0.36 + 20.0,
          top: 80.0,
          left: 16.0,
          right: 16.0,
        );

        return TaxiTownMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
            zoom: 13,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          padding: mapPadding,
          markers: {
            Marker(
              markerId: const MarkerId("pickup"),
              position: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
              icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: "Pickup: ${bookingState.pickup!.name}"),
            ),
            Marker(
              markerId: const MarkerId("dest"),
              position: LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
              icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: "Destination: ${bookingState.destination!.name}"),
            ),
            ..._driverMarkers.values,
          },
          polylines: buildRoutePolylines(routeInfo.points, const Color(0xFF1565FF)),
          onMapCreated: (controller) {
            _mapController = controller;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitRoute(routeInfo.points);
            });
          },
        );
      },
      error: (err, stack) => const Center(child: Text("Error fetching route")),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDraggableOptionsPanel(
    BuildContext context,
    AppModeColors activeColors,
    AsyncValue<RouteInfo?> routeInfoAsync,
    RideBookingNotifier bookingNotifier,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.36,
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
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: routeInfoAsync.when(
                  data: (routeInfo) {
                    if (routeInfo == null) {
                      return const Center(child: Text("Route info not available"));
                    }
                    _lastEstimatedFare = routeInfo.estimatedFare;

                    return ListView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        // Route summary
                        const Text(
                          "Choose a ride",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Route Stats Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text("DISTANCE", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("${routeInfo.distanceKm.toStringAsFixed(1)} km", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                ],
                              ),
                              Container(width: 1, height: 24, color: Colors.grey.shade200),
                              Column(
                                children: [
                                  const Text("DURATION", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("${routeInfo.durationMin.toStringAsFixed(0)} mins", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                                ],
                              ),
                              Container(width: 1, height: 24, color: Colors.grey.shade200),
                              Column(
                                children: [
                                  const Text("EST. FARE", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("₹${routeInfo.estimatedFare.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ride options choices (Bike, Mini, Sedan, SUV, Prime)
                        ...List.generate(5, (index) {
                          final double baseEst = _lastEstimatedFare ?? 120.0;
                          final List<Map<String, dynamic>> classes = [
                            {
                              "title": "Bike",
                              "capacity": 1,
                              "duration": "1 min",
                              "price": "₹${(baseEst * 0.55).toStringAsFixed(0)}",
                              "isEco": true,
                              "type": "bike",
                            },
                            {
                              "title": "Mini",
                              "capacity": 4,
                              "duration": "2 min",
                              "price": "₹${baseEst.toStringAsFixed(0)}",
                              "isEco": true,
                              "type": "mini",
                            },
                            {
                              "title": "Sedan",
                              "capacity": 4,
                              "duration": "4 min",
                              "price": "₹${(baseEst * 1.3).toStringAsFixed(0)}",
                              "isEco": false,
                              "type": "sedan",
                            },
                            {
                              "title": "SUV",
                              "capacity": 6,
                              "duration": "6 min",
                              "price": "₹${(baseEst * 1.8).toStringAsFixed(0)}",
                              "isEco": false,
                              "type": "suv",
                            },
                            {
                              "title": "Prime",
                              "capacity": 4,
                              "duration": "7 min",
                              "price": "₹${(baseEst * 2.3).toStringAsFixed(0)}",
                              "isEco": false,
                              "type": "prime",
                            },
                          ];

                          final option = classes[index];
                          final isSelected = _selectedClass == option['title'];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: RideOptionCard(
                              title: option['title'] as String,
                              capacity: option['capacity'] as int,
                              duration: option['duration'] as String,
                              price: option['price'] as String,
                              isEco: option['isEco'] as bool,
                              isSelected: isSelected,
                              carType: option['type'] as String,
                              onTap: () {
                                setState(() {
                                  _selectedClass = option['title'] as String;
                                });
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 16),

                        // Cash / Offers payment methods row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border, width: 1.1),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.payment_rounded, color: AppColors.textPrimary, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          "Cash",
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border, width: 1.1),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          "Offers",
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.textSecondary, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Total Fare and Confirm button
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              PrimaryButton(
                                text: _selectedClass == "Bike" ? "Book Bike" : "Confirm Ride",
                                onPressed: () {
                                  bookingNotifier.selectDriverClass(_selectedClass);
                                  bookingNotifier.confirmFare();
                                  Navigator.pushNamed(context, '/live-tracking');
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Fare",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "₹${((_lastEstimatedFare ?? 120.0) * (_selectedClass == 'Bike' ? 0.55 : _selectedClass == 'Mini' ? 1.0 : _selectedClass == 'Sedan' ? 1.3 : _selectedClass == 'SUV' ? 1.8 : 2.3)).toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  error: (err, stack) => const Center(child: Text("Error fetching route")),
                  loading: () => const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
