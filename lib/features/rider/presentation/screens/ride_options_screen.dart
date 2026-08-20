// Screen displaying available fare estimates and category selections matching reference image layout
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import '../../../../core/services/directions_service.dart';

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
  bool _isDisposed = false;

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
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _fitRoute(List<LatLng> points) async {
    if (_isDisposed || !mounted || _mapController == null || points.isEmpty) return;
    final bounds = _getBounds(points);
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
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

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
            zoom: 13,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
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
          },
          polylines: {
            Polyline(
              polylineId: const PolylineId("route_outline"),
              points: routeInfo.points,
              color: Colors.white,
              width: 10,
              jointType: JointType.round,
              endCap: Cap.roundCap,
              startCap: Cap.roundCap,
            ),
            Polyline(
              polylineId: const PolylineId("route_fill"),
              points: routeInfo.points,
              color: const Color(0xFF1565FF),
              width: 6,
              jointType: JointType.round,
              endCap: Cap.roundCap,
              startCap: Cap.roundCap,
            ),
          },
          onMapCreated: (controller) {
            _mapController = controller;
            _mapController!.setMapStyle(premiumMapStyle);
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
