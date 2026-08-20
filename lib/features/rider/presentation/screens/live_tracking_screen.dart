// Live tracking screen displaying route simulator, driver cards, and trip details
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/constants/map_style.dart';
import '../../../../core/utils/marker_utils.dart';
import '../../../../core/providers/location_provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../services/fake_location_service.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;
  bool _isDisposed = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _currentSize = 0.28;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      if (mounted) {
        setState(() {
          _currentSize = _sheetController.size;
        });
      }
    });

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
    _sheetController.dispose();
    super.dispose();
  }

  LatLngBounds _getBounds(LatLng p1, LatLng p2) {
    double minLat = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
    double maxLat = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
    double minLng = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
    double maxLng = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _fitDriverAndDestination(LatLng driverPos, LatLng destinationPos) async {
    if (_isDisposed || !mounted || _mapController == null) return;
    final bounds = _getBounds(driverPos, destinationPos);
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final bookingNotifier = ref.read(rideBookingNotifierProvider.notifier);
    final liveLocationAsync = ref.watch(liveLocationProvider);
    final activeColors = ref.watch(appModeColorsProvider);

    LatLng? driverPos;
    liveLocationAsync.whenData((pos) {
      driverPos = LatLng(pos.latitude, pos.longitude);
    });

    AsyncValue<RouteInfo?>? liveRouteInfoAsync;
    if (bookingState.status == RiderStatus.searching || bookingState.status == RiderStatus.noDriversAvailable) {
      if (bookingState.pickup != null && bookingState.destination != null) {
        final routeArg = (
          origin: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
          destination: LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
        );
        liveRouteInfoAsync = ref.watch(routeInfoProvider(routeArg));
      }
    } else {
      if (driverPos != null && bookingState.destination != null) {
        final routeArg = (
          origin: driverPos!,
          destination: LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
        );
        liveRouteInfoAsync = ref.watch(routeInfoProvider(routeArg));
      }
    }

    // Calculate responsive position for floating action buttons
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final maxAllowedBottom = screenHeight - appBarHeight - statusBarHeight - 80;
    final calculatedBottom = screenHeight * _currentSize + 16;
    final fabBottom = calculatedBottom > maxAllowedBottom ? maxAllowedBottom : calculatedBottom;

    final showDriverFabs = bookingState.status != RiderStatus.searching && bookingState.status != RiderStatus.noDriversAvailable;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            bookingNotifier.cancelRideSearch();
            Navigator.pop(context);
          },
        ),
        title: Text(
          bookingState.status == RiderStatus.searching
              ? "Finding Drivers"
              : (bookingState.status == RiderStatus.noDriversAvailable ? "No Drivers" : "Live Tracking"),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_rounded, color: AppColors.textPrimary),
            onPressed: () {
              context.showSnackBar("Connecting to Customer Support...");
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. Full-screen Map preview background
              Positioned.fill(
                child: _buildMapBackground(context, bookingState, liveLocationAsync, liveRouteInfoAsync),
              ),

              // 2. Responsive Floating action buttons directly above the sheet (Call, Message, Share)
              if (showDriverFabs)
                Positioned(
                  bottom: fabBottom,
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Call FAB
                      FloatingActionButton.small(
                        heroTag: "call_btn",
                        backgroundColor: AppColors.primary,
                        onPressed: () {
                          context.showSnackBar("Calling ${bookingState.activeRide?.driver?.name ?? 'Driver'}: ${bookingState.activeRide?.driver?.phone ?? '+91 98765 43210'}");
                        },
                        child: const Icon(Icons.phone_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      // Message FAB
                      FloatingActionButton.small(
                        heroTag: "msg_btn",
                        backgroundColor: AppColors.primary,
                        onPressed: () {
                          context.showSnackBar("Trip Completed! Navigating to Wallet...", backgroundColor: AppColors.success);
                          Future.delayed(const Duration(seconds: 1), () {
                            Navigator.pushNamed(context, '/wallet');
                          });
                        },
                        child: const Icon(Icons.forum_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      // Share FAB
                      FloatingActionButton.small(
                        heroTag: "share_btn",
                        backgroundColor: Colors.white,
                        onPressed: () {
                          context.showSnackBar("Trip link copied to clipboard!");
                        },
                        child: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),

              // 3. Draggable scrollable live tracking sheet
              _buildDraggableTrackingPanel(context, bookingState, bookingNotifier, activeColors),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapBackground(
    BuildContext context,
    RideBookingState bookingState,
    AsyncValue<dynamic> liveLocationAsync,
    AsyncValue<RouteInfo?>? liveRouteInfoAsync,
  ) {
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

    return liveLocationAsync.when(
      data: (position) {
        final driverPos = LatLng(position.latitude, position.longitude);

        if (!_isDisposed && mounted && _mapController != null && bookingState.destination != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!_isDisposed && mounted && _mapController != null && bookingState.destination != null) {
              final destPos = LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude);
              
              if (bookingState.status == RiderStatus.searching || bookingState.status == RiderStatus.noDriversAvailable) {
                if (bookingState.pickup != null) {
                  _fitDriverAndDestination(
                    LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
                    destPos,
                  );
                }
              } else {
                _fitDriverAndDestination(driverPos, destPos);
              }
            }
          });
        }

        final Set<Marker> markers = {};

        // Add driver marker only when ride is accepted/active
        if (bookingState.status != RiderStatus.searching && bookingState.status != RiderStatus.noDriversAvailable) {
          markers.add(
            Marker(
              markerId: const MarkerId("live_driver"),
              position: driverPos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: "${bookingState.activeRide?.driver?.name ?? 'Driver'} (Driver)"),
            ),
          );
        }

        if (bookingState.pickup != null) {
          markers.add(
            Marker(
              markerId: const MarkerId("pickup"),
              position: LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
              icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: "Pickup Point"),
            ),
          );
        }

        if (bookingState.destination != null) {
          markers.add(
            Marker(
              markerId: const MarkerId("destination"),
              position: LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
              icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: "Destination Point"),
            ),
          );
        }

        List<LatLng> polylinePoints = [];
        if (liveRouteInfoAsync != null) {
          liveRouteInfoAsync.whenData((info) {
            if (info != null) {
              polylinePoints = info.points;
            }
          });
        }

        if (polylinePoints.isEmpty && bookingState.pickup != null && bookingState.destination != null) {
          polylinePoints = [
            LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
            LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude),
          ];
        }

        final targetPos = (bookingState.status == RiderStatus.searching || bookingState.status == RiderStatus.noDriversAvailable)
            ? (bookingState.pickup != null ? LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude) : driverPos)
            : driverPos;

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: targetPos,
            zoom: 14.5,
          ),
          markers: markers,
          polylines: {
            if (polylinePoints.isNotEmpty) ...{
              Polyline(
                polylineId: const PolylineId("trip_route_outline"),
                points: polylinePoints,
                color: Colors.white,
                width: 10,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              ),
              Polyline(
                polylineId: const PolylineId("trip_route_fill"),
                points: polylinePoints,
                color: const Color(0xFF1565FF),
                width: 6,
                jointType: JointType.round,
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
              ),
            }
          },
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            _mapController = controller;
            _mapController!.setMapStyle(premiumMapStyle);
          },
        );
      },
      error: (err, stack) => const Center(
        child: Text("Error fetching live coordinates"),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDraggableTrackingPanel(
    BuildContext context,
    RideBookingState bookingState,
    RideBookingNotifier bookingNotifier,
    AppModeColors activeColors,
  ) {
    if (bookingState.status == RiderStatus.searching) {
      return DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.28,
        minChildSize: 0.18,
        maxChildSize: 0.92,
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
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(
                      strokeWidth: 4.0,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Looking for nearby drivers...",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Assigning the closest bike rider to you",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: PrimaryButton(
                        text: "Cancel Search",
                        onPressed: () {
                          bookingNotifier.cancelRideSearch();
                          Navigator.pop(context);
                        },
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

    if (bookingState.status == RiderStatus.noDriversAvailable) {
      return DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.28,
        minChildSize: 0.18,
        maxChildSize: 0.92,
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
                    const SizedBox(height: 24),
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red.shade500,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No drivers available nearby",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "All bike drivers are currently busy. Try again in a few moments.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                bookingNotifier.cancelRideSearch();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              text: "Try Again",
                              onPressed: () {
                                bookingNotifier.tryAgain();
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
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

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.28,
      minChildSize: 0.18,
      maxChildSize: 0.92,
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

                  // Header (Visible when collapsed: Avatar, Name, Vehicle info, ETA)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bookingState.activeRide?.driver?.name ?? "Ramesh Kumar",
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${bookingState.activeRide?.driver?.vehiclePlate ?? 'KA 03 AB 1234'} • ${bookingState.activeRide?.driver?.vehicleModel ?? 'WagonR • White'}",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "4 min",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),

                  // Expanded Details (Scrollable below the header)
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        // Trip Progress Info
                        const Text(
                          "Trip Status",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 1.5,
                                  height: 36,
                                  color: AppColors.border,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bookingState.pickup?.name ?? "Pickup Address",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    bookingState.destination?.name ?? "Destination Address",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${(bookingState.activeRide?.price != null ? (bookingState.activeRide!.price / 12) : 5.0).toStringAsFixed(1)} km • ${(bookingState.activeRide?.price != null ? (bookingState.activeRide!.price / 6) : 10.0).toStringAsFixed(0)} mins",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Payment Method Details
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payment_rounded, color: AppColors.textPrimary, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Payment: Cash",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                              ),
                              Text(
                                "₹${(bookingState.activeRide?.price ?? bookingState.price).toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: activeColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Support Actions
                        const Text(
                          "Safety & Support",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.shield_outlined, size: 18),
                                label: const Text("SOS"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  context.showSnackBar("Emergency SOS Alert Sent!");
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.support_agent_rounded, size: 18),
                                label: const Text("Support"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  context.showSnackBar("Connecting to Help Desk...");
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Cancel ride action
                        PrimaryButton(
                          text: "Cancel Ride",
                          backgroundColor: Colors.grey.shade200,
                          onPressed: () {
                            bookingNotifier.cancelRideSearch();
                            context.showSnackBar("Ride request canceled");
                            Navigator.popUntil(context, ModalRoute.withName('/'));
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
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
}
