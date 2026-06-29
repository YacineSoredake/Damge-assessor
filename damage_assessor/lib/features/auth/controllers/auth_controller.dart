import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/routes/app_routes.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';

enum AuthScreenStatus { idle, sendingOtp, otpSent, verifying, error }

class AuthController extends GetxController {
  final AuthRepository _repository;
  AuthController(this._repository);

  final phoneNumber = ''.obs;
  final status = AuthScreenStatus.idle.obs;
  final errorMessage = RxnString();
  final resendCooldown = 0.obs;

  Timer? _cooldownTimer;
  UserModel? currentUser;

  @override
  void onClose() {
    _cooldownTimer?.cancel();
    super.onClose();
  }

  /// Triggered from the login screen's "Send code" button.
  Future<void> sendOtp(String rawPhone) async {
    final formatted = _formatToE164(rawPhone);
    if (formatted == null) {
      errorMessage.value = 'Enter a valid phone number.';
      status.value = AuthScreenStatus.error;
      return;
    }

    phoneNumber.value = formatted;
    status.value = AuthScreenStatus.sendingOtp;
    errorMessage.value = null;

    await _repository.sendOtp(
      phoneNumber: formatted,
      onAutoVerified: (credential) async {
        // Android silent auto-verification — skip straight to backend exchange.
        status.value = AuthScreenStatus.verifying;
        try {
          currentUser = await _repository.signInWithAutoCredential(credential);
          _onLoginSuccess();
        } catch (e) {
          _onFailure(e);
        }
      },
      onCodeSent: () {
        status.value = AuthScreenStatus.otpSent;
        _startResendCooldown();
        Get.toNamed(AppRoutes.otpVerification);
      },
      onError: (failure) {
        errorMessage.value = failure.message;
        status.value = AuthScreenStatus.error;
      },
    );
  }

  /// Triggered from the OTP screen when the user submits the 6-digit code.
  Future<void> verifyOtp(String code) async {
    status.value = AuthScreenStatus.verifying;
    errorMessage.value = null;
    try {
      currentUser = await _repository.verifyOtp(code);
      _onLoginSuccess();
    } catch (e) {
      _onFailure(e);
    }
  }

  Future<void> resendOtp() async {
    if (resendCooldown.value > 0) return; // enforce cooldown client-side too
    await sendOtp(phoneNumber.value);
  }

  void _onLoginSuccess() {
    Get.find<SessionState>().markLoggedIn();
    Get.offAllNamed(AppRoutes.dashboard);
  }

  void _onFailure(Object e) {
    final failure = e is Failure ? e : const UnknownFailure();
    errorMessage.value = failure.message;
    status.value = AuthScreenStatus.error;
  }

  void _startResendCooldown() {
    resendCooldown.value = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown.value <= 1) {
        resendCooldown.value = 0;
        timer.cancel();
      } else {
        resendCooldown.value--;
      }
    });
  }

  /// Normalizes local input to E.164, defaulting to +213 (Algeria)
  /// per the spec, while still allowing an explicit country code.
  String? _formatToE164(String raw) {
    final trimmed = raw.trim().replaceAll(' ', '');
    if (trimmed.startsWith('+')) return trimmed;
    if (trimmed.startsWith('0') && trimmed.length >= 9) {
      return '+213${trimmed.substring(1)}';
    }
    if (trimmed.length >= 9) return '+213$trimmed';
    return null;
  }
}
