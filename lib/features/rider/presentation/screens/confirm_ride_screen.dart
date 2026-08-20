// Ride booking confirmation screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../services/fake_location_service.dart';
import '../../../../services/fake_tracking_service.dart';
import '../../providers/ride_provider.dart';
import '../widgets/map_preview.dart';

class ConfirmRideScreen extends ConsumerWidget {
  const ConfirmRideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(rideBookingNotifierProvider);
    final bookingNotifier = ref.read(rideBookingNotifierProvider.notifier);

    ref.listen<String?>(rideErrorProvider, (previous, next) {
      if (next != null) {
        context.showSnackBar(next, backgroundColor: Colors.red);
        ref.read(rideErrorProvider.notifier).state = null;
      }
    });

    if (bookingState.pickup == null || bookingState.destination == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            "Missing route locations",
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }

    final distance = FakeLocationService.calculateDistance(
      bookingState.pickup!,
      bookingState.destination!,
    );
    final durationMin = (distance * 2.2).ceil();
    final routeCoords = FakeTrackingService.interpolatePoints(
      bookingState.pickup!,
      bookingState.destination!,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Map preview (40% height)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: AppMapWidget(
              pickup: bookingState.pickup,
              destination: bookingState.destination,
              routePoints: routeCoords,
            ),
          ),

          // 2. Floating back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. Bottom Card (overlapping sheet)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.63,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "Confirm Booking Details",
                      style: AppTextStyles.headingMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Route tiles
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.circle, color: Color(0xFF2E7D32), size: 10),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        bookingState.pickup!.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: AppColors.border, height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        bookingState.destination!.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Fare and journey spec rows
                          _buildSpecRow("Estimated Distance", "${distance.toStringAsFixed(1)} km"),
                          const Divider(color: AppColors.border),
                          _buildSpecRow("Estimated Time", "$durationMin mins"),
                          const Divider(color: AppColors.border),
                          _buildSpecRow("Ride Price", "\$${bookingState.price.toStringAsFixed(2)}"),
                          const Divider(color: AppColors.border),
                          _buildSpecRow("Payment Method", "Cash (Default)"),
                          const Divider(color: AppColors.border),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions Buttons
                  ElevatedButton(
                    onPressed: () {
                      bookingNotifier.confirmFare();
                      Navigator.pushNamed(context, '/live-tracking');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text("Confirm Ride", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text("Edit Route", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
