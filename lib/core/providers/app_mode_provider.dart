// App Mode state notifier and theme color mappings provider
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { rider, driver }

class AppModeColors {
  final Color primary;
  final Color secondary;
  final Color lightAccent;
  final Color background;
  final Color cardBackground;
  final Color elevatedCardBackground;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final String label;
  final String subtitle;
  final bool isDark;

  const AppModeColors({
    required this.primary,
    required this.secondary,
    required this.lightAccent,
    required this.background,
    required this.cardBackground,
    required this.elevatedCardBackground,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.label,
    required this.subtitle,
    required this.isDark,
  });
}

// Global provider tracking rider vs driver modes
final appModeProvider = StateProvider<AppMode>((ref) => AppMode.rider);

// Provider exposing accent color palettes dynamically according to active mode
final appModeColorsProvider = Provider<AppModeColors>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode == AppMode.rider) {
    return const AppModeColors(
      primary: Color(0xFF1565FF),
      secondary: Color(0xFF3B82F6),
      lightAccent: Color(0xFFEAF2FF),
      background: Color(0xFFF8FAFC),
      cardBackground: Color(0xFFFFFFFF),
      elevatedCardBackground: Color(0xFFFFFFFF),
      border: Color(0xFFE5E7EB),
      textPrimary: Color(0xFF111827),
      textSecondary: Color(0xFF6B7280),
      label: 'Rider Mode',
      subtitle: 'Book a ride',
      isDark: false,
    );
  } else {
    return const AppModeColors(
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF60A5FA),
      lightAccent: Color(0xFF1F2937),
      background: Color(0xFF0B1020),
      cardBackground: Color(0xFF111827),
      elevatedCardBackground: Color(0xFF1F2937),
      border: Color(0xFF243042),
      textPrimary: Color(0xFFF9FAFB),
      textSecondary: Color(0xFF9CA3AF),
      label: 'Driver Mode',
      subtitle: 'Earn money',
      isDark: true,
    );
  }
});
