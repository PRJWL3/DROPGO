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
import '../../../../core/providers/location_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/constants/map_style.dart';
import '../../../../core/utils/marker_utils.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../shared/widgets/primary_button.dart';
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
  bool _isDisposed = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
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
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: 15.0,
        ),
      ),
    );
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
    final mode = ref.watch(appModeProvider);
    final activeColors = ref.watch(appModeColorsProvider);
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final isRouteSelected = bookingState.pickup != null && bookingState.destination != null;

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

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: initialZoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      markers: markers,
      polylines: polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        _mapController!.setMapStyle(premiumMapStyle);
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200, width: 1.1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bookingState.destination?.name ?? "Where do you want to go?",
                                style: TextStyle(
                                  color: bookingState.destination != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

                    const Text(
                      "Recent & Saved Places",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        final categories = [
                          {'label': 'Market', 'icon': Icons.storefront_rounded},
                          {'label': 'Hospital', 'icon': Icons.add_box_rounded},
                          {'label': 'Bus Stand', 'icon': Icons.directions_bus_rounded},
                          {'label': 'Airport', 'icon': Icons.flight_takeoff_rounded},
                        ];
                        final cat = categories[index];
                        return QuickPlaceCard(
                          label: cat['label'] as String,
                          icon: cat['icon'] as IconData,
                          onTap: () {
                            ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                            Navigator.pushNamed(context, '/search');
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEAF2FF),
                              child: Icon(Icons.home_rounded, color: AppColors.primary, size: 20),
                            ),
                            title: const Text("Home", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text("Ramapuram, Anantapur", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEAF2FF),
                              child: Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
                            ),
                            title: const Text("College", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: const Text("Alliance University", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            onTap: () {
                              ref.read(rideBookingNotifierProvider.notifier).startSelectingRoute();
                              Navigator.pushNamed(context, '/search');
                            },
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
