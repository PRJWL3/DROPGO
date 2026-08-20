// Incoming ride request overlay display containing countdown rings and passenger route summaries
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../../rider/presentation/widgets/map_preview.dart';

class IncomingRideRequestScreen extends ConsumerStatefulWidget {
  const IncomingRideRequestScreen({super.key});

  @override
  ConsumerState<IncomingRideRequestScreen> createState() => _IncomingRideRequestScreenState();
}

class _IncomingRideRequestScreenState extends ConsumerState<IncomingRideRequestScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  String? _rideId;
  Map<String, dynamic>? _rideData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 60 seconds countdown timer
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Auto-dismiss when countdown ends
        if (mounted) {
          context.showSnackBar("Ride request expired");
          Navigator.pop(context);
        }
      }
    });

    _timerController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideId == null) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is String) {
        _rideId = args;
        _loadRideDetails();
      } else {
        // Fallback for mock preview
        _rideId = "mock_ride_id";
        _loadRideDetails();
      }
    }
  }

  void _loadRideDetails() async {
    if (_rideId == null) return;
    final data = await FirebaseService.getRide(_rideId!);
    if (mounted) {
      setState(() {
        _rideData = data;
        _isLoading = false;
      });
    }
  }

  void _acceptRide() async {
    if (_rideId == null) return;

    _timerController.stop();

    setState(() {
      _isLoading = true;
    });

    final error = await FirebaseService.acceptRide(
      rideId: _rideId!,
      driverId: "d_ramesh",
      driverName: "Ramesh Kumar",
      driverVehicleNumber: "KA-05-AA-5678",
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error == null) {
      context.showSnackBar("Ride request accepted!", backgroundColor: Colors.green);
      Navigator.pushReplacementNamed(context, '/driver-to-pickup');
    } else {
      context.showSnackBar(error, backgroundColor: Colors.red);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: activeColors.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final hasData = _rideData != null;
    final riderName = _rideData?['riderName'] as String? ?? "Passenger";
    final pickup = _rideData?['pickupAddress'] as String? ?? "Pickup Address";
    final dest = _rideData?['destinationAddress'] as String? ?? "Destination Address";
    final distance = _rideData?['distanceKm'] as double? ?? 1.2;
    final duration = _rideData?['estimatedDurationMinutes'] as double? ?? 14.0;
    final fare = _rideData?['estimatedFare'] as double? ?? 68.0;

    // Driver gets 85% of fare as estimated earnings
    final earnings = fare * 0.85;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map preview background
          Positioned.fill(
            child: AppMapWidget(
              isSelectingPickup: false,
              isSelectingDestination: false,
            ),
          ),

          // Dimmed backdrop filter overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // 2. Floating Request Dialog Card in Center
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: activeColors.cardBackground,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: activeColors.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      "New Ride Request",
                      style: TextStyle(
                        color: activeColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Countdown ring around rider photo
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated progress indicator ring
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: AnimatedBuilder(
                            animation: _timerController,
                            builder: (context, child) {
                              return CircularProgressIndicator(
                                value: 1.0 - _timerController.value,
                                strokeWidth: 5,
                                backgroundColor: activeColors.border,
                                valueColor: AlwaysStoppedAnimation<Color>(activeColors.primary),
                              );
                            },
                          ),
                        ),
                        // Circular avatar
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: activeColors.primary.withOpacity(0.12),
                          child: Icon(Icons.person_rounded, color: activeColors.primary, size: 36),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Rider Name and Rating
                  Center(
                    child: Text(
                      riderName,
                      style: TextStyle(
                        color: activeColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        "4.9",
                        style: TextStyle(
                          color: activeColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Route Location points (Pickup & Destination)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: activeColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: activeColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildRouteRow(
                          iconColor: const Color(0xFF10B981),
                          title: "Pickup",
                          address: pickup,
                          activeColors: activeColors,
                        ),
                        Divider(height: 20, thickness: 1.0, color: activeColors.border),
                        _buildRouteRow(
                          iconColor: activeColors.primary,
                          title: "Destination",
                          address: dest,
                          activeColors: activeColors,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Trip specs (Distance, Fare, Time)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSpecItem("Distance", "${distance.toStringAsFixed(1)} km", activeColors),
                      _buildSpecItem("Earnings", "₹${earnings.toStringAsFixed(0)}", activeColors),
                      _buildSpecItem("Trip Time", "${duration.toStringAsFixed(0)} min", activeColors),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Reject / Accept Actions Buttons
                  Row(
                    children: [
                      // Reject Outlined Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: activeColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            "Reject",
                            style: TextStyle(
                              color: activeColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Accept Solid Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _acceptRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Accept",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow({
    required Color iconColor,
    required String title,
    required String address,
    required AppModeColors activeColors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, color: iconColor, size: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: activeColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  color: activeColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecItem(String label, String value, AppModeColors activeColors) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: activeColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
