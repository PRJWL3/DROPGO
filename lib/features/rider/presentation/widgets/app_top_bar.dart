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
    final activeColors = ref.watch(appModeColorsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: activeColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: SafeArea(
        child: Row(
          children: [
            // Hamburger Menu Icon
            GestureDetector(
              onTap: onMenuTap,
              child: Icon(
                Icons.menu_rounded,
                color: activeColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Animated Header (Fade & Scale transition)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey(mode), // rebuild transition when mode toggles
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          mode == AppMode.rider ? Icons.directions_car_rounded : Icons.local_taxi_rounded,
                          color: activeColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activeColors.label,
                          style: TextStyle(
                            color: activeColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      activeColors.subtitle,
                      style: TextStyle(
                        color: activeColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                final newMode = mode == AppMode.rider ? AppMode.driver : AppMode.rider;
                ref.read(appModeProvider.notifier).state = newMode;
                if (newMode == AppMode.driver) {
                  Navigator.pushNamedAndRemoveUntil(context, '/driver-home', (route) => false);
                } else {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: activeColors.lightAccent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeColors.primary.withOpacity(0.3), width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      mode == AppMode.rider ? Icons.person_rounded : Icons.directions_car_rounded,
                      color: activeColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mode == AppMode.rider ? "Rider" : "Driver",
                      style: TextStyle(
                        color: activeColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Notification Bell with Badge count
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: onNotificationTap,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: activeColors.textPrimary,
                    size: 24,
                  ),
                ),
                if (notificationCount > 0)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: activeColors.primary,
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
