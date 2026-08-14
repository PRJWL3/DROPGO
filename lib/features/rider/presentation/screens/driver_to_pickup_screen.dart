// Driver navigation route guide screen showing full map guides and rider context actions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../widgets/map_preview.dart';

class DriverToPickupScreen extends ConsumerWidget {
  const DriverToPickupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeColors = ref.watch(appModeColorsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen map background
          Positioned.fill(
            child: AppMapWidget(
              isSelectingPickup: false,
              isSelectingDestination: false,
            ),
          ),

          // 2. Floating Top Overlay Card (ETA, Distance, Rider Info)
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "ETA 4 min",
                        style: TextStyle(
                          color: activeColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Distance 1.2 km",
                        style: TextStyle(
                          color: activeColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: activeColors.primary,
                        child: const Icon(Icons.person, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Rider: Priya",
                        style: TextStyle(
                          color: activeColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
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
                  Text(
                    "PICKUP ADDRESS",
                    style: TextStyle(
                      color: activeColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: activeColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Ramapuram Market, Bengaluru",
                          style: TextStyle(
                            color: activeColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Actions row (Call, Message, Maps)
                  Row(
                    children: [
                      _buildRoundAction(Icons.phone_rounded, "Call Rider", () {
                        context.showSnackBar("Calling Priya...");
                      }, activeColors),
                      _buildRoundAction(Icons.forum_rounded, "Message", () {
                        context.showSnackBar("Opening Chat with Priya...");
                      }, activeColors),
                      _buildRoundAction(Icons.explore_rounded, "Google Maps", () {
                        context.showSnackBar("Redirecting to external navigation...");
                      }, activeColors),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Primary Arrived button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/driver-arrived');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "I've arrived",
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

          // 4. Floating back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: activeColors.cardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: activeColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: activeColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
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
          child: Column(
            children: [
              Icon(icon, color: activeColors.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColors.textPrimary,
                  fontSize: 11,
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
