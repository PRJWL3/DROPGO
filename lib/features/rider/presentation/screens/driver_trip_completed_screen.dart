// Screen displaying final ride metrics, payment collections, and earnings breakdowns
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';

class DriverTripCompletedScreen extends ConsumerStatefulWidget {
  const DriverTripCompletedScreen({super.key});

  @override
  ConsumerState<DriverTripCompletedScreen> createState() => _DriverTripCompletedScreenState();
}

class _DriverTripCompletedScreenState extends ConsumerState<DriverTripCompletedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isCashCollected = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      backgroundColor: activeColors.background,
      appBar: AppBar(
        backgroundColor: activeColors.cardBackground,
        elevation: 0.5,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "Trip Completed",
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // 1. Success check scaling animation
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: activeColors.lightAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: activeColors.primary,
                      size: 64,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  "Nice Job, Ramesh!",
                  style: TextStyle(
                    color: activeColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  "You have safely dropped Priya at the destination",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: activeColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 2. Earnings Breakdown Card
              Container(
                decoration: BoxDecoration(
                  color: activeColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: activeColors.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: activeColors.textPrimary.withOpacity(0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EARNINGS BREAKDOWN",
                      style: TextStyle(
                        color: activeColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBreakdownRow("Trip fare", "₹68", activeColors),
                    const SizedBox(height: 12),
                    _buildBreakdownRow("TaxiTown fee", "-₹5", activeColors),
                    Divider(height: 28, color: activeColors.border, thickness: 1.2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Driver earnings",
                          style: TextStyle(
                            color: activeColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "₹63",
                          style: TextStyle(
                            color: const Color(0xFF10B981), // success green
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Payment Status Card
              Container(
                decoration: BoxDecoration(
                  color: activeColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeColors.border, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment_rounded, color: activeColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Payment Mode",
                          style: TextStyle(
                            color: activeColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _isCashCollected ? "Cash Collected (₹68)" : "Cash Pending (₹68)",
                      style: TextStyle(
                        color: _isCashCollected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 4. Action Buttons (Collect cash, Done)
              if (!_isCashCollected) ...[
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isCashCollected = true;
                    });
                    context.showSnackBar(
                      "Cash marked as collected",
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: activeColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Collect Cash",
                    style: TextStyle(
                      color: activeColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton(
                onPressed: _isCashCollected
                    ? () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/driver-home',
                          (route) => false,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCashCollected ? activeColors.primary : activeColors.border,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "Done",
                  style: TextStyle(
                    color: _isCashCollected ? Colors.white : activeColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, AppModeColors activeColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: activeColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: activeColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
