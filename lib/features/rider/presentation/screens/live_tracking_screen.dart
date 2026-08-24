// Live tracking screen displaying route simulator, driver cards, and trip details
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/maps/taxi_town_map_widget.dart';
import '../../../../core/maps/taxi_town_map_camera.dart';
import '../../../../core/maps/taxi_town_map_config.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/constants/map_style.dart';
import '../../../../core/utils/marker_utils.dart';
import '../../../../core/providers/location_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/driver_location_provider.dart';
import '../../models/ride_model.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/services/firebase_service.dart';
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
  double _mapPaddingBottom = 220.0;

  RiderStatus? _lastFitStatus;
  LatLng? _lastFitDriverPos;

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
        targetPadding = 0.92 * screenHeight + 24.0;
      }
      if ((targetPadding - _mapPaddingBottom).abs() > 5.0) {
        if (mounted) {
          setState(() {
            _mapPaddingBottom = targetPadding;
          });
          debugPrint("TRACKING MAP PADDING SNAPPED TO: $_mapPaddingBottom");
        }
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
    return TaxiTownMapCamera.getBounds([p1, p2]);
  }

  void _maybeFitBounds(RiderStatus status, LatLng start, LatLng end) {
    if (_isDisposed || !mounted || _mapController == null) return;
    
    bool shouldFit = (status != _lastFitStatus);
    
    if (_lastFitDriverPos != null) {
      final distance = Geolocator.distanceBetween(
        _lastFitDriverPos!.latitude,
        _lastFitDriverPos!.longitude,
        start.latitude,
        start.longitude,
      );
      if (distance > 100.0) {
        shouldFit = true;
      }
    } else {
      shouldFit = true;
    }
    
    if (shouldFit) {
      _lastFitStatus = status;
      _lastFitDriverPos = start;
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_isDisposed || !mounted || _mapController == null) return;
        final bounds = _getBounds(start, end);
        await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final bookingNotifier = ref.read(rideBookingNotifierProvider.notifier);
    final liveLocationAsync = ref.watch(liveLocationProvider);
    final activeColors = ref.watch(appModeColorsProvider);

    ref.listen<RideBookingState>(rideBookingNotifierProvider, (previous, next) {
      if (next.status == RiderStatus.completed && previous?.status != RiderStatus.completed) {
        _showReachedAndRatingDialog(context, ref);
      }
    });

    LatLng? driverPos;
    final assignedDriverId = bookingState.activeRide?.driver?.id;
    if (assignedDriverId != null && FirebaseService.isFirebaseAvailable) {
      ref.watch(assignedDriverLocationProvider(assignedDriverId)).whenData((driverData) {
        final lat = (driverData['currentLatitude'] as num?)?.toDouble();
        final lng = (driverData['currentLongitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          driverPos = LatLng(lat, lng);
        }
      });
    }

    if (driverPos == null) {
      liveLocationAsync.whenData((pos) {
        driverPos = LatLng(pos.latitude, pos.longitude);
      });
    }

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

    // Calculate responsive position constraints for floating action buttons
    final screenHeight = MediaQuery.sizeOf(context).height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final maxAllowedBottom = screenHeight - appBarHeight - statusBarHeight - 80;

    final showDriverFabs = bookingState.status != RiderStatus.searching && bookingState.status != RiderStatus.noDriversAvailable;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          bookingNotifier.cancelRideSearch();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        title: Text(
          bookingState.status == RiderStatus.searching
              ? "Finding Drivers"
              : (bookingState.status == RiderStatus.noDriversAvailable 
                  ? "No Drivers" 
                  : (bookingState.status == RiderStatus.accepted 
                      ? "Driver is on the way" 
                      : (bookingState.status == RiderStatus.arriving 
                          ? "Driver has arrived" 
                          : "Trip in Progress"))),
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
                child: _buildMapBackground(context, bookingState, liveLocationAsync, liveRouteInfoAsync, driverPos),
              ),

              // 2. Responsive Floating action buttons directly above the sheet (Call, Message, Share)
              if (showDriverFabs)
                ListenableBuilder(
                  listenable: _sheetController,
                  builder: (context, child) {
                    final currentSize = _sheetController.isAttached ? _sheetController.size : 0.28;
                    final calculatedBottom = screenHeight * currentSize + 16;
                    final fabBottom = calculatedBottom > maxAllowedBottom ? maxAllowedBottom : calculatedBottom;
                    return Positioned(
                      bottom: fabBottom,
                      right: 16,
                      child: child!,
                    );
                  },
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
    ),
  );
}

  Widget _buildMapBackground(
    BuildContext context,
    RideBookingState bookingState,
    AsyncValue<dynamic> liveLocationAsync,
    AsyncValue<RouteInfo?>? liveRouteInfoAsync,
    LatLng? driverPos,
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
        final LatLng userPos = LatLng(position.latitude, position.longitude);
        final LatLng activeDriverPos = driverPos ?? userPos;

        if (!_isDisposed && mounted && _mapController != null && bookingState.destination != null) {
          final destPos = LatLng(bookingState.destination!.latitude, bookingState.destination!.longitude);
          
          if (bookingState.status == RiderStatus.searching || bookingState.status == RiderStatus.noDriversAvailable) {
            if (bookingState.pickup != null) {
              _maybeFitBounds(
                bookingState.status,
                LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude),
                destPos,
              );
            }
          } else {
            _maybeFitBounds(bookingState.status, activeDriverPos, destPos);
          }
        }

        final Set<Marker> markers = {};

        // Add driver marker only when ride is accepted/active
        if (bookingState.status != RiderStatus.searching && bookingState.status != RiderStatus.noDriversAvailable) {
          markers.add(
            Marker(
              markerId: const MarkerId("live_driver"),
              position: activeDriverPos,
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
            ? (bookingState.pickup != null ? LatLng(bookingState.pickup!.latitude, bookingState.pickup!.longitude) : activeDriverPos)
            : activeDriverPos;

        final mapPadding = EdgeInsets.only(
          bottom: _mapPaddingBottom,
          top: 100.0,
          left: 16.0,
          right: 16.0,
        );

        return TaxiTownMap(
          initialCameraPosition: CameraPosition(
            target: targetPos,
            zoom: 14.5,
          ),
          markers: markers,
          polylines: buildRoutePolylines(polylinePoints, const Color(0xFF1565FF)),
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          padding: mapPadding,
          onMapCreated: (controller) {
            _mapController = controller;
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
                        if (bookingState.status == RiderStatus.accepted || bookingState.status == RiderStatus.arriving) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "Your ride OTP",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bookingState.activeRide?.otp ?? "----",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Tell this OTP to your driver to start the ride.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  void _showReachedAndRatingDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(rideBookingNotifierProvider);
    final ride = state.activeRide;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _ReachedRatingDialog(
          rideId: ride?.id ?? "",
          driverName: ride?.driver?.name ?? "Ramesh Kumar",
          destinationAddress: ride?.destination.name ?? "Destination",
          price: ride?.price ?? 0.0,
          onSubmit: (rating, feedback) {
            ref.read(rideBookingNotifierProvider.notifier).rateDriver(rating);
            Navigator.of(ctx).pop();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      },
    );
  }
}

class _ReachedRatingDialog extends StatefulWidget {
  final String rideId;
  final String driverName;
  final String destinationAddress;
  final double price;
  final Function(double rating, String feedback) onSubmit;

  const _ReachedRatingDialog({
    required this.rideId,
    required this.driverName,
    required this.destinationAddress,
    required this.price,
    required this.onSubmit,
  });

  @override
  State<_ReachedRatingDialog> createState() => _ReachedRatingDialogState();
}

class _ReachedRatingDialogState extends State<_ReachedRatingDialog> {
  double _rating = 5.0;
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF22C55E),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              "You've Reached!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Thank you for riding with us.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Fare",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "₹${widget.price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              "How was your driver, ${widget.driverName}?",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _rating;
                return IconButton(
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = starIndex.toDouble();
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _feedbackController,
              decoration: InputDecoration(
                hintText: "Write a feedback (optional)...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                widget.onSubmit(_rating, _feedbackController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Submit & Go Home",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
