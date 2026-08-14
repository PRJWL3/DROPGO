// Reusable double-row location address picker card widget
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class LocationCard extends StatelessWidget {
  final String? pickupName;
  final String? destinationName;
  final VoidCallback onTapPickup;
  final VoidCallback onTapDestination;
  final VoidCallback onTapTarget;

  const LocationCard({
    super.key,
    this.pickupName,
    this.destinationName,
    required this.onTapPickup,
    required this.onTapDestination,
    required this.onTapTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left visual connector column (dots & dashed line)
          Column(
            children: [
              const SizedBox(height: 18),
              // Blue circle indicator
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              // Dashed divider line
              Container(
                width: 1.5,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: List.generate(4, (index) {
                    return Container(
                      width: 1.5,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 3),
                      color: AppColors.border,
                    );
                  }),
                ),
              ),
              // Blue Pin Location Indicator
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Address detail rows Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Pickup Location details
                InkWell(
                  onTap: onTapPickup,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "My Location",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pickupName ?? "Bengaluru, Karnataka",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: onTapTarget,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.lightBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gps_fixed_rounded,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 28, color: AppColors.border, thickness: 1),

                // Bottom Row: Destination Location details
                InkWell(
                  onTap: onTapDestination,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Where to go?",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              destinationName ?? "Enter destination",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
