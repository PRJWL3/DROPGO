// Screen displaying passenger arrival details and OTP verification prompts
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/services/firebase_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/maps/taxi_town_map_widget.dart';

class DriverArrivedScreen extends ConsumerStatefulWidget {
  const DriverArrivedScreen({super.key});

  @override
  ConsumerState<DriverArrivedScreen> createState() => _DriverArrivedScreenState();
}

class _DriverArrivedScreenState extends ConsumerState<DriverArrivedScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  bool _isOtpValid = false;
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  
  String? _rideId;
  Map<String, dynamic>? _rideData;
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _otpController.addListener(() {
      final input = _otpController.text.trim();
      if (input.length == 4) {
        if (!_isOtpValid) {
          setState(() {
            _isOtpValid = true;
          });
        }
      } else {
        if (_isOtpValid) {
          setState(() {
            _isOtpValid = false;
          });
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
        _loadRideDetails();
      } else {
        _rideId = "mock_ride_id";
        _loadRideDetails();
      }
    }
  }

  void _loadRideDetails() async {
    if (_rideId == null) return;
    setState(() {
      _isLoading = true;
    });
    final data = await FirebaseService.getRide(_rideId!);
    if (mounted) {
      setState(() {
        _rideData = data;
        _isLoading = false;
      });
    }
  }

  void _verifyAndStartRide() async {
    final pin = _otpController.text.trim();
    if (pin.length != 4 || _rideId == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final error = await FirebaseService.verifyRideOtp(
      rideId: _rideId!,
      driverId: "d_ramesh",
      submittedOtp: pin,
    );

    // Dev log requirements:
    debugPrint("Ride ID: $_rideId");
    debugPrint("Current ride status: accepted");
    debugPrint("Driver ID: d_ramesh");
    debugPrint("OTP verification result: ${error == null ? 'SUCCESS' : 'FAILED'}");

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (error == null) {
      setState(() {
        _isOtpValid = true;
      });
      _successController.forward();
      
      context.showSnackBar("OTP Verified! Starting ride...", backgroundColor: Colors.green);
      
      // Update global active ride ID provider (Step 14)
      ref.read(activeDriverRideIdProvider.notifier).state = _rideId;

      // Navigate to real navigation screen after a short animation delay
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/driver-trip-in-progress', arguments: _rideId);
        }
      });
    } else {
      setState(() {
        _errorMessage = "Incorrect OTP. Please try again.";
        _otpController.clear();
        _isOtpValid = false;
      });
      _successController.reverse();
      context.showSnackBar("Incorrect OTP", backgroundColor: Colors.red);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map preview background
          Positioned.fill(
            child: _rideData == null
                ? const Center(child: CircularProgressIndicator())
                : TaxiTownMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (_rideData!['pickupLatitude'] as num?)?.toDouble() ?? 12.9716,
                        (_rideData!['pickupLongitude'] as num?)?.toDouble() ?? 77.5946,
                      ),
                      zoom: 15.0,
                    ),
                    myLocationEnabled: false,
                  ),
          ),

          // Dimmed backdrop
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // 2. Center OTP Verification Dialog Card
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
                      "Verify Rider",
                      style: TextStyle(
                        color: activeColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Rider details row
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
                                "Pickup: ${_rideData?['pickupAddress'] ?? 'Ramapuram Market'}",
                                style: TextStyle(
                                  color: activeColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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

                    Divider(height: 28, color: activeColors.border),

                    Center(
                      child: Text(
                        "Ask the rider for their 4-digit OTP.",
                        style: TextStyle(
                          color: activeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Animated Success Checkmark Ring
                    Center(
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: activeColors.lightAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981), // green success check
                            size: 32,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // OTP Input field
                    TextField(
                      controller: _otpController,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      enabled: !_isVerifying,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: activeColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: "••••",
                        counterText: "",
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        filled: true,
                        fillColor: activeColors.elevatedCardBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: activeColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: activeColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: activeColors.primary),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Verify & Start Ride Button
                    ElevatedButton(
                      onPressed: (_otpController.text.trim().length == 4 && !_isVerifying)
                          ? _verifyAndStartRide
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_otpController.text.trim().length == 4 && !_isVerifying)
                            ? activeColors.primary
                            : activeColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Verify & Start Ride",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
