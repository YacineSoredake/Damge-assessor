import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_storage.dart';
import 'models/user_model.dart';

/// Wraps Firebase Phone Auth for OTP send/verify, then exchanges the
/// resulting Firebase ID token for our own backend JWT via
/// POST /auth/firebase — per the architecture decided in the spec.
class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  /// Starts phone verification. Handles both the Android auto-retrieval
  /// path (calls onAutoVerified directly) and the manual-code path
  /// (calls onCodeSent so the UI can show the OTP entry screen).
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function() onCodeSent,
    required void Function(Failure failure) onError,
  }) async {
    if (kIsWeb) {
      try {
        final confirmationResult =
            await _firebaseAuth.signInWithPhoneNumber(phoneNumber);
        _confirmationResult = confirmationResult;
        onCodeSent();
      } on FirebaseAuthException catch (e) {
        onError(_mapFirebaseError(e));
      }
      return;
    }

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) {
        // Android auto-verification — no manual code entry needed.
        onAutoVerified(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(_mapFirebaseError(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Verifies the manually-entered OTP code.
  Future<UserModel> verifyOtp(String smsCode) async {
    if (kIsWeb) {
      if (_confirmationResult == null) {
        throw const AuthFailure(
            'No verification in progress. Please request a new code.');
      }
      return _signInWithConfirmationResult(_confirmationResult!, smsCode);
    }

    if (_verificationId == null) {
      throw const AuthFailure(
          'No verification in progress. Please request a new code.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    return _signInWithCredential(credential);
  }

  /// Used for the Android auto-verification path.
  Future<UserModel> signInWithAutoCredential(PhoneAuthCredential credential) {
    return _signInWithCredential(credential);
  }

  Future<UserModel> _signInWithCredential(
      PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw const UnknownFailure('Could not retrieve Firebase ID token.');
      }
      return _exchangeForBackendSession(idToken);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<UserModel> _signInWithConfirmationResult(
      ConfirmationResult confirmationResult, String smsCode) async {
    try {
      final userCredential = await confirmationResult.confirm(smsCode);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw const UnknownFailure('Could not retrieve Firebase ID token.');
      }
      return _exchangeForBackendSession(idToken);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  /// Sends the Firebase ID token to our backend, which verifies it via
  /// the Firebase Admin SDK, creates/looks up the user row, and returns
  /// our own backend JWT + user profile.
  Future<UserModel> _exchangeForBackendSession(String firebaseIdToken) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/firebase',
        data: {'firebase_id_token': firebaseIdToken},
      );
      final backendToken = response.data['token'] as String;
      await LocalStorage.instance.saveToken(backendToken);
      return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkFailure();
      }
      throw const ServerFailure();
    }
  }

  Failure _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return const OtpInvalidFailure();
      case 'session-expired':
        return const OtpExpiredFailure();
      case 'too-many-requests':
        return const TooManyAttemptsFailure();
      case 'network-request-failed':
        return const NetworkFailure();
      default:
        return AuthFailure(e.message ?? 'Authentication failed.');
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await LocalStorage.instance.clearToken();
  }
}
