// Reusable transaction list item tile matching reference design specs
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TransactionType.credit;
    final amountPrefix = isCredit ? "+ " : "- ";
    final amountColor = isCredit ? AppColors.success : AppColors.danger;

    // Use blue car icon for rides, gold card icon for deposits
    final iconColor = isCredit ? const Color(0xFFD97706) : AppColors.primary;
    final iconBgColor = isCredit ? const Color(0xFFFEF3C7) : AppColors.lightBlue;
    final iconData = isCredit ? Icons.account_balance_wallet_rounded : Icons.directions_car_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Left transaction icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Center Title and Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.date,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Right Price amount in Indian Rupee
          Text(
            "$amountPrefix\₹${transaction.amount.toStringAsFixed(0)}",
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
