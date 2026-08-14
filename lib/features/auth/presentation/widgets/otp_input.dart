// Reusable text input for OTP verification codes
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class OtpInput extends StatelessWidget {
  final TextEditingController controller;

  const OtpInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: 8.0,
        ),
        decoration: const InputDecoration(
          hintText: "••••••",
          hintStyle: TextStyle(color: AppColors.textSecondary, letterSpacing: 4.0),
          border: InputBorder.none,
          counterText: "",
          isDense: true,
        ),
      ),
    );
  }
}
