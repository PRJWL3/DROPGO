// Driver wallet screen showing balances, payouts, and commission histories
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_mode_provider.dart';
import '../../../../core/utils/extensions.dart';

class DriverWalletScreen extends ConsumerStatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  ConsumerState<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends ConsumerState<DriverWalletScreen>
    with SingleTickerProviderStateMixin {
  int _selectedFilterIndex = 1; // "This week" selected by default
  double _balance = 1240.0;

  final List<String> _filters = ["Today", "This week", "This month"];

  final List<Map<String, dynamic>> _commissionHistory = [
    {
      "title": "Ride to MG Road",
      "date": "Today, 08:45 PM",
      "fare": 120.0,
      "fee": 10.0,
      "net": 110.0,
      "type": "ride",
    },
    {
      "title": "Ride to Airport",
      "date": "Today, 09:05 AM",
      "fare": 280.0,
      "fee": 20.0,
      "net": 260.0,
      "type": "ride",
    },
    {
      "title": "Added Balance",
      "date": "Yesterday, 04:30 PM",
      "fare": 500.0,
      "fee": 0.0,
      "net": 500.0,
      "type": "deposit",
    },
    {
      "title": "Ride to Indiranagar",
      "date": "Yesterday, 08:10 AM",
      "fare": 160.0,
      "fee": 12.0,
      "net": 148.0,
      "type": "ride",
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          "Earnings Wallet",
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
            const SizedBox(height: 16),

            // 1. Large Blue Gradient Balance Card (dynamic blue gradient in driver mode)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: activeColors.isDark
                      ? [const Color(0xFF2563EB), const Color(0xFF60A5FA)]
                      : [const Color(0xFF1565FF), const Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: activeColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AVAILABLE BALANCE",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${_balance.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions row (Withdraw, Add balance, Payouts)
                  Row(
                    children: [
                      _buildCardAction("Withdraw", () {
                        setState(() {
                          _balance = 0.0;
                        });
                        context.showSnackBar("Payout of ₹1,240 initiated successfully!");
                      }),
                      const SizedBox(width: 8),
                      _buildCardAction("Add Balance", () {
                        setState(() {
                          _balance += 500.0;
                        });
                        context.showSnackBar("Added ₹500 to driver wallet!");
                      }),
                      const SizedBox(width: 8),
                      _buildCardAction("Payouts", () {
                        context.showSnackBar("Opening Payout Statement logs...");
                      }),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Custom Painted Weekly Payout Chart
            Text(
              "Weekly Earnings Chart",
              style: TextStyle(
                color: activeColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: activeColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activeColors.border, width: 1.2),
              ),
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: EarningsChartPainter(
                  primaryColor: activeColors.primary,
                  secondaryColor: activeColors.secondary,
                  labelColor: activeColors.textSecondary,
                  gridColor: activeColors.border,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Filter Sections Row (Today, This Week, This Month)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_filters.length, (index) {
                final isSelected = _selectedFilterIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilterIndex = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? activeColors.primary : activeColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? activeColors.primary : activeColors.border,
                          width: 1.1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : activeColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // 4. Commission History List
            Text(
              "Commission History",
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
                children: List.generate(_commissionHistory.length, (index) {
                  final item = _commissionHistory[index];
                  final isLast = index == _commissionHistory.length - 1;
                  final isDeposit = item['type'] == 'deposit';

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Left type Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: activeColors.lightAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDeposit ? Icons.account_balance_wallet_rounded : Icons.directions_car_rounded,
                                color: activeColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Center details (Ride fare & fee breakdown)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      color: activeColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isDeposit
                                        ? "Deposit: ₹${item['fare']}"
                                        : "Fare: ₹${item['fare']} • Fee: -₹${item['fee']}",
                                    style: TextStyle(
                                      color: activeColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right Net Earnings
                            Text(
                              isDeposit ? "+₹${item['net']}" : "₹${item['net']}",
                              style: TextStyle(
                                color: isDeposit ? activeColors.primary : const Color(0xFF10B981), // success green
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: activeColors.border,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAction(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30, width: 1.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom Painter: Premium Weekly Earnings Bar Chart
class EarningsChartPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color labelColor;
  final Color gridColor;

  EarningsChartPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.labelColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Draw horizontal grid lines
    canvas.drawLine(Offset(0, h * 0.25), Offset(w, h * 0.25), gridPaint);
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), gridPaint);
    canvas.drawLine(Offset(0, h * 0.75), Offset(w, h * 0.75), gridPaint);

    final barPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final activeBarPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    // 7 days weekly values percentages
    final values = [0.4, 0.65, 0.3, 0.85, 0.5, 0.95, 0.2];
    final days = ["M", "T", "W", "T", "F", "S", "S"];

    final double barWidth = w * 0.06;
    final double spacing = w * 0.08;
    final double startX = w * 0.05;

    for (int i = 0; i < values.length; i++) {
      final double x = startX + i * (barWidth + spacing);
      final double barHeight = h * 0.7 * values[i];
      final double y = h * 0.85 - barHeight;

      // Draw rounded bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        i == 5 ? activeBarPaint : barPaint, // Highlight Saturday active peak
      );

      // Draw day label text
      final textPainter = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(color: labelColor, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + barWidth / 2 - textPainter.width / 2, h * 0.88));
    }
  }

  @override
  bool shouldRepaint(covariant EarningsChartPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.gridColor != gridColor;
  }
}
