// Screen displaying passenger arrival details and OTP verification prompts
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../widgets/map_preview.dart';

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
      if (input == "4827") {
        if (!_isOtpValid) {
          setState(() {
            _isOtpValid = true;
          });
          _successController.forward();
        }
      } else {
        if (_isOtpValid) {
          setState(() {
            _isOtpValid = false;
          });
          _successController.reverse();
        }
      }
    });
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
            child: AppMapWidget(
              isSelectingPickup: false,
              isSelectingDestination: false,
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
                      "Verify Passenger OTP",
                      style: TextStyle(
                        color: activeColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              "Rider: Priya",
                              style: TextStyle(
                                color: activeColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Pickup: Ramapuram Market",
                              style: TextStyle(
                                color: activeColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Divider(height: 28, color: activeColors.border),

                  // Large OTP Reference Display
                  Center(
                    child: Text(
                      "PASSENGER OTP",
                      style: TextStyle(
                        color: activeColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "4827",
                      style: TextStyle(
                        color: activeColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 24),

                  // Start Trip Button
                  ElevatedButton(
                    onPressed: _isOtpValid
                        ? () {
                            Navigator.pushNamed(context, '/driver-trip-in-progress');
                          }
                        : null, // Disabled when OTP is invalid
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOtpValid ? activeColors.primary : activeColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Start Trip",
                      style: TextStyle(
                        color: _isOtpValid ? Colors.white : activeColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
