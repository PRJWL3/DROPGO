// Driver navigation screen showing active passenger ride progress and telemetry updates
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../widgets/map_preview.dart';

class DriverTripInProgressScreen extends ConsumerStatefulWidget {
  const DriverTripInProgressScreen({super.key});

  @override
  ConsumerState<DriverTripInProgressScreen> createState() => _DriverTripInProgressScreenState();
}

class _DriverTripInProgressScreenState extends ConsumerState<DriverTripInProgressScreen> {
  Timer? _updateTimer;
  double _remainingDistance = 4.2;
  int _remainingTime = 8;
  double _currentFare = 34.0;

  @override
  void initState() {
    super.initState();
    // Simulate active vehicle coordinates progress and fare incrementation
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingDistance > 0.2) {
            _remainingDistance -= 0.3;
          } else {
            _remainingDistance = 0.0;
          }

          if (_remainingTime > 1) {
            _remainingTime -= 1;
          } else {
            _remainingTime = 0;
          }

          if (_currentFare < 68.0) {
            _currentFare += 4.25;
          } else {
            _currentFare = 68.0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen map background showing route lines
          Positioned.fill(
            child: AppMapWidget(
              isSelectingPickup: false,
              isSelectingDestination: false,
            ),
          ),

          // 2. Floating Top Overlay telemetry Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: activeColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeColors.border, width: 1.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTopStat("TIME REMAINING", "$_remainingTime min", activeColors),
                  _buildVerticalDivider(activeColors),
                  _buildTopStat("DISTANCE", "${_remainingDistance.toStringAsFixed(1)} km", activeColors),
                  _buildVerticalDivider(activeColors),
                  _buildTopStat("CURRENT FARE", "₹${_currentFare.toStringAsFixed(0)}", activeColors),
                ],
              ),
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
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rider Profile details
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
                              "Destination: Anantapur Bus Stand",
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
                  const SizedBox(height: 20),

                  // Actions row (Call, Share)
                  Row(
                    children: [
                      _buildRoundAction(Icons.phone_rounded, "Call Rider", () {
                        context.showSnackBar("Calling Priya...");
                      }, activeColors),
                      _buildRoundAction(Icons.share_rounded, "Share Trip", () {
                        context.showSnackBar("Trip link copied successfully!");
                      }, activeColors),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Primary End Trip button (using danger red always)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/driver-trip-completed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444), // danger red
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "End Trip",
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
        ],
      ),
    );
  }

  Widget _buildTopStat(String label, String value, AppModeColors activeColors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: activeColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(AppModeColors activeColors) {
    return Container(
      width: 1.2,
      height: 24,
      color: activeColors.border,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: activeColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColors.textPrimary,
                  fontSize: 12,
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
