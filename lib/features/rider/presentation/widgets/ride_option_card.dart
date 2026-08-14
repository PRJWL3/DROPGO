// Premium choosing card for ride categories matching the design spec
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class RideOptionCard extends StatelessWidget {
  final String title;
  final int capacity;
  final String duration;
  final String price;
  final bool isEco;
  final bool isSelected;
  final VoidCallback onTap;
  final String carType; // 'mini', 'sedan', 'suv', 'prime'

  const RideOptionCard({
    super.key,
    required this.title,
    required this.capacity,
    required this.duration,
    required this.price,
    this.isEco = false,
    required this.isSelected,
    required this.onTap,
    required this.carType,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightBlue.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Left custom drawn car side profile
            Container(
              width: 72,
              height: 48,
              margin: const EdgeInsets.only(right: 12),
              child: CustomPaint(
                painter: SideCarPainter(
                  carType: carType,
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                ),
              ),
            ),

            // Middle details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // capacity + duration row
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        "$capacity",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        duration,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  // Optional Green Eco label row
                  if (isEco) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.eco_rounded, size: 12, color: AppColors.success),
                        SizedBox(width: 2),
                        Text(
                          "Eco",
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Right Price info
            Text(
              price,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),

            const SizedBox(width: 12),

            // Selector Check Status dot
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 0.0 : 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 13,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Side car vector profile drawing
class SideCarPainter extends CustomPainter {
  final String carType;
  final Color color;

  SideCarPainter({required this.carType, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;

    final path = Path();

    if (carType == 'mini') {
      // Hatchback drawing
      path.moveTo(w * 0.1, h * 0.7);
      path.lineTo(w * 0.05, h * 0.6);
      path.quadraticBezierTo(w * 0.05, h * 0.4, w * 0.15, h * 0.35);
      path.lineTo(w * 0.4, h * 0.3);
      path.lineTo(w * 0.6, h * 0.15);
      path.lineTo(w * 0.8, h * 0.15);
      path.lineTo(w * 0.9, h * 0.45);
      path.lineTo(w * 0.95, h * 0.6);
      path.lineTo(w * 0.9, h * 0.7);
      path.close();
    } else if (carType == 'sedan') {
      // Sedan drawing
      path.moveTo(w * 0.05, h * 0.7);
      path.lineTo(w * 0.05, h * 0.55);
      path.lineTo(w * 0.2, h * 0.45);
      path.lineTo(w * 0.35, h * 0.2);
      path.lineTo(w * 0.7, h * 0.2);
      path.lineTo(w * 0.8, h * 0.45);
      path.lineTo(w * 0.95, h * 0.5);
      path.lineTo(w * 0.95, h * 0.7);
      path.close();
    } else if (carType == 'suv') {
      // Boxy SUV drawing
      path.moveTo(w * 0.05, h * 0.7);
      path.lineTo(w * 0.05, h * 0.4);
      path.lineTo(w * 0.25, h * 0.2);
      path.lineTo(w * 0.85, h * 0.2);
      path.lineTo(w * 0.9, h * 0.5);
      path.lineTo(w * 0.95, h * 0.7);
      path.close();
    } else {
      // Premium Sedan drawing
      path.moveTo(w * 0.05, h * 0.7);
      path.lineTo(w * 0.05, h * 0.52);
      path.lineTo(w * 0.22, h * 0.42);
      path.lineTo(w * 0.4, h * 0.15);
      path.lineTo(w * 0.75, h * 0.15);
      path.lineTo(w * 0.82, h * 0.42);
      path.lineTo(w * 0.95, h * 0.48);
      path.lineTo(w * 0.95, h * 0.7);
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);

    // Wheels
    final wheelPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.28, h * 0.7), w * 0.12, wheelPaint);
    canvas.drawCircle(Offset(w * 0.28, h * 0.7), w * 0.06, rimPaint);

    canvas.drawCircle(Offset(w * 0.72, h * 0.7), w * 0.12, wheelPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.7), w * 0.06, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
