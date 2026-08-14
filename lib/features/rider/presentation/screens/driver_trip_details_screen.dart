// Driver trip details summary display containing pickup, destinations, and fares
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../widgets/map_preview.dart';

class DriverTripDetailsScreen extends ConsumerWidget {
  const DriverTripDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      backgroundColor: activeColors.background,
      appBar: AppBar(
        backgroundColor: activeColors.cardBackground,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: activeColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Trip Details",
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Map preview (50% height)
          Expanded(
            flex: 50,
            child: AppMapWidget(
              isSelectingPickup: false,
              isSelectingDestination: false,
            ),
          ),

          // 2. Summary details panel (50% height)
          Expanded(
            flex: 50,
            child: Container(
              color: activeColors.cardBackground,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "TRIP COMPLETED",
                        style: TextStyle(
                          color: activeColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        "Earning: ₹260",
                        style: const TextStyle(
                          color: Color(0xFF10B981), // success green
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: Colors.grey, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "12 Aug 2026, 09:30 AM",
                        style: TextStyle(color: Colors.grey, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Divider(height: 24, color: activeColors.border, thickness: 1.1),

                  // Route details
                  _buildAddressPoint("Pickup", "Ramapuram Market, Bengaluru", const Color(0xFF10B981), activeColors),
                  const SizedBox(height: 12),
                  _buildAddressPoint("Destination", "Airport Terminal 2, Bengaluru", activeColors.primary, activeColors),

                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildAddressPoint(String label, String address, Color dotColor, AppModeColors activeColors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.circle, color: dotColor, size: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
}
