// Screen displaying user wallet statistics and recent transactions matching the reference layout
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../models/transaction_model.dart';
import '../../providers/wallet_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_stat_card.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  int _currentNavIndex = 2; // Wallet active by default

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletNotifierProvider);
    final walletNotifier = ref.read(walletNotifierProvider.notifier);

    final transactions = walletState.transactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Wallet",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // 1. Large Gradient Balance Card
                  Container(
                    height: 170,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Wallet 3D visual on the right
                        Positioned(
                          right: 16,
                          top: 16,
                          bottom: 16,
                          width: 100,
                          child: CustomPaint(
                            painter: WalletVisualPainter(),
                          ),
                        ),

                        // Balance detail texts on the left
                        Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Wallet Balance",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${walletState.balance.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Spacer(),

                              // "+ Add Money" pill button
                              InkWell(
                                onTap: () {
                                  walletNotifier.addFunds(500.0);
                                  context.showSnackBar("Simulated top-up of ₹500 successful!");
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, color: AppColors.primary, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        "Add Money",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Stats Cards Row
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WalletStatCard(
                        title: "Trips This Month",
                        value: "12",
                        icon: Icons.directions_car_rounded,
                      ),
                      WalletStatCard(
                        title: "Total Spent",
                        value: "₹2,340",
                        icon: Icons.bar_chart_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Recent Transactions Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Transactions",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.showSnackBar("Showing complete statement history");
                        },
                        child: const Text(
                          "View All",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Recent Transactions Rounded Card Container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      children: List.generate(transactions.length, (index) {
                        final tx = transactions[index];
                        final isLast = index == transactions.length - 1;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TransactionTile(transaction: tx),
                            ),
                            if (!isLast)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.border,
                                indent: 16,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Referral Invite Friends Card
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF), // light blue container background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary.withOpacity(0.12), width: 1.2),
                    ),
                    child: Stack(
                      children: [
                        // Gift bow custom painter on right
                        Positioned(
                          right: 12,
                          top: 12,
                          bottom: 12,
                          width: 100,
                          child: CustomPaint(
                            painter: GiftVisualPainter(),
                          ),
                        ),

                        // Detail labels on left
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 120, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Invite Friends, Earn More",
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Invite a friend and get ₹100 in your wallet after their first ride.",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),

                              // Invite Now pill button
                              InkWell(
                                onTap: () {
                                  context.showSnackBar("Referral code copied to clipboard!");
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Invite Now",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom navigation bar
          BottomNavBar(
            currentIndex: _currentNavIndex,
            onTap: (index) {
              setState(() {
                _currentNavIndex = index;
              });
              if (index == 0) {
                Navigator.pushNamed(context, '/');
              } else if (index == 1) {
                Navigator.pushNamed(context, '/history');
              } else if (index == 3) {
                Navigator.pushNamed(context, '/profile');
              }
            },
          ),
        ],
      ),
    );
  }
}

// Custom Painter: Blue Gradient Wallet Card Visual
class WalletVisualPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Draw card outlines
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8),
        const Radius.circular(12),
      ),
      paint,
    );

    // Draw wallet pouch
    final pouchPaint = Paint()
      ..color = Colors.white.withOpacity(0.24)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.75, h * 0.65),
        const Radius.circular(10),
      ),
      pouchPaint,
    );

    // Draw metal clip buckle in gold
    final bucklePaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.82, h * 0.58), 6, bucklePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter: Gift Box Vector illustration
class GiftVisualPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw white box backing
    final boxPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final boxRect = Rect.fromLTWH(w * 0.2, h * 0.35, w * 0.6, h * 0.5);
    canvas.drawRect(boxRect, boxPaint);
    canvas.drawRect(boxRect, strokePaint);

    // Draw blue ribbon stripe
    final ribbonPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.35, w * 0.1, h * 0.5), ribbonPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.2, h * 0.55, w * 0.6, h * 0.08), ribbonPaint);

    // Draw ribbon loops/bows on top
    final loopPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final Path bowPath = Path();
    bowPath.moveTo(w * 0.5, h * 0.35);
    bowPath.cubicTo(w * 0.35, h * 0.2, w * 0.45, h * 0.15, w * 0.5, h * 0.35);
    bowPath.cubicTo(w * 0.65, h * 0.2, w * 0.55, h * 0.15, w * 0.5, h * 0.35);
    canvas.drawPath(bowPath, loopPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
