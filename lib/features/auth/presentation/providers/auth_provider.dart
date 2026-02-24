import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/network/api_constants.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/leave/presentation/providers/leave_approve_provider.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';
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

  // ─────────────────────────────────────────────
  // 🔁 AUTO LOGIN
  // ─────────────────────────────────────────────

  Future<void> tryAutoLogin() async {
    final jwt = await _tokenStorage.getJwt();
    if (jwt == null || jwt.isEmpty) return;

    try {
      state = state.copyWith(isLoading: true);

      final profileJson = await _authApi.fetchProfile();
      final profile = Userdetails.fromJson(profileJson);

      print("🏢 RAW company object: ${profileJson['company']}");
      print("🏢 logo_filename raw: ${profile.companyLogoFilename}");

      final companyLogoUrl = profile.companyLogoFilename != null
          ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
          : '';

      print("🏢 FINAL companyLogoUrl: $companyLogoUrl");

      final permissions = await _authApi.fetchPermissions();

      state = state.copyWith(
        isLoading: false,
        profile: profile,
        permissions: permissions,

        profileUrl: profile.profilePicture != null
            ? ApiConstants.imageBaseUrl + profile.profilePicture!
            : '',

        companyLogoUrl: profile.companyLogoFilename != null
            ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
            : '',
      );

      // 🔔 REGISTER FCM TOKEN (AUTO LOGIN)
      await _registerFcmIfAvailable();
    } catch (_) {
      await _tokenStorage.clear();
      state = const AuthState();
    }
  }

  // ─────────────────────────────────────────────
  // 🔐 LOGIN
  // ─────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final userModel = await _authApi.login(email, password);
      await _tokenStorage.saveJwt(userModel.token);

      ref.invalidate(notificationProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(leaveApproveProvider);

      final profileJson = await _authApi.fetchProfile();
      final profile = Userdetails.fromJson(profileJson);

      print("🏢 RAW company object: ${profileJson['company']}");
      print("🏢 logo_filename raw: ${profile.companyLogoFilename}");

      final companyLogoUrl = profile.companyLogoFilename != null
          ? ApiConstants.companyLogoBaseUrl + profile.companyLogoFilename!
          : '';

      print("🏢 FINAL companyLogoUrl: $companyLogoUrl");

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

      // 🔔 REGISTER FCM TOKEN (LOGIN)
      await _registerFcmIfAvailable();
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // 🔑 FORGOT PASSWORD (SEND OTP)
  // ─────────────────────────────────────────────

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true);

    try {
      await _authApi.forgotPassword(email);
    } catch (_) {
      rethrow;
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
    } catch (_) {
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─────────────────────────────────────────────
  // 🔑 CHANGE PASSWORD
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // 🖼️ UPDATE PROFILE IMAGE
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // 🖼️ Upload profile image
  // ─────────────────────────────────────────────

  Future<void> uploadProfileImage(File file) async {
    try {
      state = state.copyWith(isLoading: true);

      await _authApi.uploadProfileImage(file);

      // refresh profile
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

  // ─────────────────────────────────────────────
  // 🚪 LOGOUT
  // ─────────────────────────────────────────────

  Future<void> logout() async {
    final fcmToken = await _tokenStorage.getFcm();

    if (fcmToken != null && fcmToken.isNotEmpty) {
      try {
        await _authApi.unregisterFcmToken(fcmToken: fcmToken);
      } catch (_) {}
    }

    await _tokenStorage.clear();

    ref.invalidate(notificationProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(leaveApproveProvider);

    state = const AuthState();

    /// 🔥 Proper full Riverpod reset
    Root.restartApp();
  }

  // ─────────────────────────────────────────────
  // 🔔 HELPERS
  // ─────────────────────────────────────────────

  Future<void> _registerFcmIfAvailable() async {
    final fcmToken = await _tokenStorage.getFcm();

    if (fcmToken == null || fcmToken.isEmpty) {
      return;
    }

    try {
      await _authApi.registerFcmToken(
        fcmToken: fcmToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      // backend failure should NOT break login
    }
  }

  Future<void> registerFcmTokenIfNeeded() async {
    await _registerFcmIfAvailable();
  }
}
