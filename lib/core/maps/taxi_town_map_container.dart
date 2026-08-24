import 'package:flutter/material.dart';

/// Reusable decorative wrapper for maps embedded in cards or panels
class TaxiTownMapContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final Color borderColor;

  const TaxiTownMapContainer({
    super.key,
    required this.child,
    this.height,
    this.borderColor = const Color(0xFFE2E8F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
