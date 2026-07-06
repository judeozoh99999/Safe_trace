import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginState {
  final int step; // 0 = Phone, 1 = OTP
  final String phoneNumber;
  final String otpCode;
  final bool isLoading;
  final String? errorMessage;
  final int resendCountdown;

  LoginState({
    this.step = 0,
    this.phoneNumber = '',
    this.otpCode = '',
    this.isLoading = false,
    this.errorMessage,
    this.resendCountdown = 30,
  });

  LoginState copyWith({
    int? step,
    String? phoneNumber,
    String? otpCode,
    bool? isLoading,
    String? errorMessage,
    int? resendCountdown,
  }) {
    return LoginState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otpCode: otpCode ?? this.otpCode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      resendCountdown: resendCountdown ?? this.resendCountdown,
    );
  }
}

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier() : super(LoginState());

  void setPhoneNumber(String phone) {
    state = state.copyWith(phoneNumber: phone);
  }

  void setOtpCode(String code) {
    state = state.copyWith(otpCode: code);
  }

  void nextStep() {
    state = state.copyWith(step: 1);
  }

  void prevStep() {
    state = state.copyWith(step: 0);
  }

  void startLoading() {
    state = state.copyWith(isLoading: true, errorMessage: null);
  }

  void stopLoading() {
    state = state.copyWith(isLoading: false);
  }

  void setError(String message) {
    state = state.copyWith(isLoading: false, errorMessage: message);
  }
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier();
});
