import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/main.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/auth_api_service.dart';
import 'auth_state.dart';
import '../../../profile/data/models/user_details_model.dart';
import 'auth_api_providers.dart';

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  late final AuthApiService _authApi;
  late final TokenStorage _tokenStorage;

  @override
  AuthState build() {
    _authApi = ref.read(authApiServiceProvider);
    _tokenStorage = ref.read(tokenStorageProvider);
    return const AuthState();
  }

  // ───────────────── AUTO LOGIN ─────────────────

  Future<void> tryAutoLogin() async {
    final jwt = await _tokenStorage.getJwt();

    /// ❌ No token → go to login
    if (jwt == null || jwt.isEmpty) {
      state = const AuthState(isLoading: false, isInitializing: false);
      return;
    }

    try {
      /// Auto login loading
      state = state.copyWith(isLoading: true, isSubscriptionExpired: false);

      final profileJson = await _authApi.fetchProfile();

      /// Subscription expired
      if (_isSubscriptionExpired(profileJson)) {
        await _tokenStorage.clear();

        forceSubscriptionExpired();
        return;
      }

      final profile = Userdetails.fromJson(profileJson);
      final permissions = await _authApi.fetchPermissions();

      /// ✅ Auto login success
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        profile: profile,
        permissions: permissions,
        profileUrl: profile.profilePicture != null
            ? ApiConstants.imageBaseUrl + profile.profilePicture!
            : '',
        companyLogoUrl: profile.companyLogoFilename != null
            ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
            : '',
      );

      await _registerFcmIfAvailable();
    } catch (e) {
      final message = e.toString().toLowerCase();

      if (message.contains("expired") || message.contains("402")) {
        state = const AuthState(
          isLoading: false,
          isInitializing: false,
          isSubscriptionExpired: true,
        );

        forceSubscriptionExpired();
        return;
      }

      /// Token invalid → clear and go to login
      await _tokenStorage.clear();

      state = const AuthState(isLoading: false, isInitializing: false);
    }
  }

  // ───────────────── LOGIN ─────────────────

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, isSubscriptionExpired: false);

    try {
      final userModel = await _authApi.login(email, password);

      await _tokenStorage.saveJwt(userModel.token);

      final profileJson = await _authApi.fetchProfile();

      if (_isSubscriptionExpired(profileJson)) {
        forceSubscriptionExpired();
        return;
      }

      final profile = Userdetails.fromJson(profileJson);
      final permissions = await _authApi.fetchPermissions();

      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        isSubscriptionExpired: false,
        authUser: userModel.user,
        profile: profile,
        permissions: permissions,
        profileUrl: profile.profilePicture != null
            ? ApiConstants.imageBaseUrl + profile.profilePicture!
            : '',
        companyLogoUrl: profile.companyLogoFilename != null
            ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
            : '',
      );

      await _registerFcmIfAvailable();

      Future.microtask(() {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      });
    } catch (e, stack) {
      print("🧨 LOGIN CATCH TRIGGERED");
      print("🧨 ERROR TYPE: ${e.runtimeType}");
      print("🧨 ERROR VALUE: $e");

      state = state.copyWith(isLoading: false, isInitializing: false);

      if (e is DioException) {
        final status = e.response?.statusCode;
        final body = e.response?.data;

        print("🧨 DIO STATUS: $status");
        print("🧨 DIO BODY: $body");

        /// Invalid credentials
        if (status == 401) {
          ref
              .read(globalLoadingProvider.notifier)
              .showError("Invalid email or password");
          return;
        }

        /// Subscription expired
        if (status == 402) {
          forceSubscriptionExpired();
          return;
        }
      }

      /// Fallback error
      ref
          .read(globalLoadingProvider.notifier)
          .showError("Unable to login. Please try again.");
    }
  }

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true);

    final overlay = ref.read(globalLoadingProvider.notifier);

    try {
      await _authApi.sendOtp(phone);

      state = state.copyWith(isLoading: false);

      overlay.showSuccess("OTP sent successfully");
    } catch (e) {
      state = state.copyWith(isLoading: false);

      if (e is DioException) {
        final msg = e.response?.data?["message"] ?? "Failed to send OTP";
        overlay.showError(msg);
      } else {
        overlay.showError("Failed to send OTP");
      }
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    state = state.copyWith(isLoading: true, isSubscriptionExpired: false);

    try {
      final userModel = await _authApi.verifyOtp(phone: phone, otp: otp);

      await _tokenStorage.saveJwt(userModel.token);

      final profileJson = await _authApi.fetchProfile();

      if (_isSubscriptionExpired(profileJson)) {
        forceSubscriptionExpired();
        return;
      }

      final profile = Userdetails.fromJson(profileJson);
      final permissions = await _authApi.fetchPermissions();

      state = state.copyWith(
        isLoading: false,
        authUser: userModel.user,
        profile: profile,
        permissions: permissions,
        profileUrl: profile.profilePicture != null
            ? ApiConstants.imageBaseUrl + profile.profilePicture!
            : '',
        companyLogoUrl: profile.companyLogoFilename != null
            ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
            : '',
      );

      await _registerFcmIfAvailable();
    } catch (e) {
      state = state.copyWith(isLoading: false);

      final overlay = ref.read(globalLoadingProvider.notifier);

      if (e is DioException) {
        final msg = e.response?.data?["message"] ?? "OTP verification failed";
        overlay.showError(msg);
      } else {
        overlay.showError("OTP verification failed");
      }
    }
  }

  // ───────────────── SUBSCRIPTION CHECK ─────────────────

  bool _isSubscriptionExpired(Map<String, dynamic> profileJson) {
    try {
      final endDateStr = profileJson['company']?['subscription_end_date'];

      if (endDateStr == null) return false;

      final endDate = DateTime.parse(endDateStr).toLocal();
      final now = DateTime.now();

      return now.isAfter(endDate);
    } catch (_) {
      return false;
    }
  }

  // ───────────────── FORGOT PASSWORD ─────────────────

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true);

    try {
      await _authApi.forgotPassword(email);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _authApi.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ───────────────── CHANGE PASSWORD ─────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _authApi.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ───────────────── PROFILE IMAGE ─────────────────

  Future<void> uploadProfileImage(File file) async {
    try {
      state = state.copyWith(isLoading: true);

      await _authApi.uploadProfileImage(file);

      final profileJson = await _authApi.fetchProfile();
      final profile = Userdetails.fromJson(profileJson);

      state = state.copyWith(
        profile: profile,
        profileUrl: profile.profilePicture != null
            ? ApiConstants.imageBaseUrl + profile.profilePicture!
            : '',
        companyLogoUrl: profile.companyLogoFilename != null
            ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
            : '',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // ───────────────── LOGOUT ─────────────────

  Future<void> logout() async {
    final jwt = await _tokenStorage.getJwt();
    final fcmToken = await _tokenStorage.getFcm();

    if (jwt != null &&
        jwt.isNotEmpty &&
        fcmToken != null &&
        fcmToken.isNotEmpty) {
      try {
        await _authApi.unregisterFcmToken(fcmToken: fcmToken);
      } catch (_) {}
    }

    await _tokenStorage.clear();

    state = const AuthState();

    Root.restartApp();
  }

  // ───────────────── SUBSCRIPTION STATE ─────────────────
  void forceSubscriptionExpired() {
    state = state.copyWith(
      isInitializing: false,
      isSubscriptionExpired: true,
      isLoading: false,
    );

    Future.microtask(() {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/subscription-expired',
        (route) => false,
      );
    });
  }

  void resetSubscriptionExpired() {
    state = state.copyWith(isSubscriptionExpired: false, isInitializing: false);

    Future.microtask(() {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  // ───────────────── FCM HELPERS ─────────────────

  Future<void> _registerFcmIfAvailable() async {
    final fcmToken = await _tokenStorage.getFcm();

    if (fcmToken == null || fcmToken.isEmpty) return;

    try {
      await _authApi.registerFcmToken(
        fcmToken: fcmToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {}
  }

  Future<void> registerFcmTokenIfNeeded() async {
    await _registerFcmIfAvailable();
  }
}
