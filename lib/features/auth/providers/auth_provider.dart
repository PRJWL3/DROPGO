// Auth notifier provider for log/OTP verification simulation
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class AuthNotifier extends StateNotifier<UserModel> {
  AuthNotifier() : super(const UserModel());

  void sendOtp(String phoneNumber) {
    state = state.copyWith(phoneNumber: phoneNumber);
  }

  bool verifyOtp(String otp) {
    if (otp == '123456') {
      state = state.copyWith(
        uid: 'user_1234',
        name: 'Alex Rider',
        isLoggedIn: true,
      );
      return true;
    }
    return false;
  }

  void logout() {
    state = const UserModel();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel>((ref) {
  return AuthNotifier();
});
