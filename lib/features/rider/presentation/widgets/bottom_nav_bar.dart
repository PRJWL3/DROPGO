// Reusable floating bottom navigation bar dock widget
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';

class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final activeColors = ref.watch(appModeColorsProvider);

    // Build navigation tabs list depending on active AppMode (Rider vs Driver)
    final tabs = mode == AppMode.rider
        ? [
            {'label': 'Home', 'icon': Icons.home_rounded},
            {'label': 'Trips', 'icon': Icons.directions_car_rounded},
            {'label': 'Wallet', 'icon': Icons.account_balance_wallet_rounded},
            {'label': 'Profile', 'icon': Icons.person_rounded},
          ]
        : [
            {'label': 'Dashboard', 'icon': Icons.dashboard_rounded},
            {'label': 'Trips', 'icon': Icons.directions_car_rounded},
            {'label': 'Wallet', 'icon': Icons.account_balance_wallet_rounded},
            {'label': 'Profile', 'icon': Icons.person_rounded},
          ];

    return Container(
      height: 72 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: activeColors.cardBackground,
        border: Border(
          top: BorderSide(color: activeColors.border, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: activeColors.textPrimary.withOpacity(0.04),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isActive = index == currentIndex;
          final color = isActive ? activeColors.primary : activeColors.textSecondary;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tab['icon'] as IconData,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tab['label'] as String,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
