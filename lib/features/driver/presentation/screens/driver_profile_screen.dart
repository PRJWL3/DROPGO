// Driver profile screen displaying active ratings, online time, and account configurations
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

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
          "Driver Profile",
          style: TextStyle(
            color: activeColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // Profile info block
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: activeColors.primary.withOpacity(0.12),
                    child: Icon(Icons.person_rounded, color: activeColors.primary, size: 50),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Ramesh Kumar",
                    style: TextStyle(
                      color: activeColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Joined August 2026",
                    style: TextStyle(
                      color: activeColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Account settings cards
            Text(
              "Account details",
              style: TextStyle(
                color: activeColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: activeColors.cardBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: activeColors.border, width: 1.2),
              ),
              child: Column(
                children: [
                  _buildProfileTile(Icons.directions_car_rounded, "Vehicle Info", "Maruti Suzuki Swift (KA-03-ME-1294)", activeColors),
                  Divider(height: 1, color: activeColors.border),
                  _buildProfileTile(Icons.verified_user_rounded, "Licenses & Permits", "Verified Driver Class", activeColors),
                  Divider(height: 1, color: activeColors.border),
                  _buildProfileTile(Icons.star_rounded, "Rating Score", "4.9 Stars Average", activeColors),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Log out buttons
            ElevatedButton(
              onPressed: () {
                ref.read(appModeProvider.notifier).state = AppMode.rider;
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Sign Out (Rider Mode)",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, AppModeColors activeColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: activeColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: activeColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: activeColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: activeColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}
