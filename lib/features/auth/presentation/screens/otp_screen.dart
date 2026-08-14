// Screen for entering SMS verification code
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../providers/auth_provider.dart';
import '../widgets/otp_input.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _onVerifyOtp() {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      context.showSnackBar("Verification code must be 6 digits");
      return;
    }
    final success = ref.read(authProvider.notifier).verifyOtp(otp);
    if (success) {
      context.showSnackBar("Verification Successful! Welcome to TaxiTown.");
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      context.showSnackBar("Invalid verification code. Hint: Use 123456");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Verify Phone",
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: 12),
              Text(
                "We sent a 6-digit verification code to +91 ${userState.phoneNumber ?? ''}",
                style: AppTextStyles.bodyMedium,
              ),
              const Spacer(),
              OtpInput(controller: _otpController),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _onVerifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 1,
                ),
                child: const Text(
                  "Verify & Proceed",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
