// Premium app top bar header displaying active mode headers and mode selectors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final int notificationCount;

  const AppTopBar({
    super.key,
    required this.onMenuTap,
    required this.onNotificationTap,
    this.notificationCount = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Hamburger Menu Icon
            GestureDetector(
              onTap: onMenuTap,
              child: const Icon(
                Icons.menu_rounded,
                color: Color(0xFF0F172A),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // DropGo Logo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1565FF),
                        size: 24,
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        "DROPGO",
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    "Book a ride, anytime",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Double Pill Mode Switcher
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (mode != AppMode.rider) {
                        ref.read(appModeProvider.notifier).state = AppMode.rider;
                        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: mode == AppMode.rider ? const Color(0xFF1565FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_car_rounded,
                            color: mode == AppMode.rider ? Colors.white : const Color(0xFF64748B),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Rider",
                            style: TextStyle(
                              color: mode == AppMode.rider ? Colors.white : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (mode != AppMode.driver) {
                        ref.read(appModeProvider.notifier).state = AppMode.driver;
                        Navigator.pushNamedAndRemoveUntil(context, '/driver-home', (route) => false);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: mode == AppMode.driver ? const Color(0xFF1565FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sports_motorsports_rounded,
                            color: mode == AppMode.driver ? Colors.white : const Color(0xFF64748B),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Driver",
                            style: TextStyle(
                              color: mode == AppMode.driver ? Colors.white : const Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Notification Bell with Badge count
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: onNotificationTap,
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF0F172A),
                    size: 26,
                  ),
                ),
                if (notificationCount > 0)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1565FF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "$notificationCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
