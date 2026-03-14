import 'dart:io';
import 'package:dio/dio.dart';
import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/features/auth/data/models/user_model.dart';
import '../../../../core/network/api_service.dart';

class AuthApiService {
  final ApiService api;

  AuthApiService(this.api);

  // ───────────────── AUTH ─────────────────

  Future<UserModel> login(String email, String password) async {
    final response = await api.post(ApiEndpoints.login, {
      'email': email,
      'password': password,
    });

    return UserModel.fromJson(response);
  }

  Future<void> sendOtp(String phone) async {
    await api.post(ApiEndpoints.sendOtp, {"phone": phone});
  }

  Future<UserModel> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await api.post(ApiEndpoints.verifyOtp, {
      "phone": phone,
      "otp": otp,
    });

    return UserModel.fromJson(response);
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    return await api.get(ApiEndpoints.userDetails);
  }

  Future<List<String>> fetchPermissions() async {
    final response = await api.get(ApiEndpoints.permissions);

    final List list = response['permissions'];
    return list.map((p) => p['name'] as String).toList();
  }

  // ───────────────── PASSWORD ─────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await api.post(ApiEndpoints.changePassword, {
      "currentPassword": currentPassword,
      "newPassword": newPassword,
      "confirmPassword": confirmPassword,
    });
  }

  Future<void> forgotPassword(String email) async {
    await api.post(ApiEndpoints.forgotPassword, {"email": email});
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await api.post(ApiEndpoints.resetPassword, {
      "email": email,
      "otp": otp,
      "newPassword": newPassword,
    });
  }

  // ───────────────── PROFILE IMAGE ─────────────────

  Future<String> uploadProfileImage(File file) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    final response = await api.postMultipart(
      ApiEndpoints.profileImage,
      formData,
    );

    return response['filename'];
  }

  // ───────────────── FCM ─────────────────

  Future<void> registerFcmToken({
    required String fcmToken,
    required String platform,
  }) async {
    await api.post(ApiEndpoints.registerFcmToken, {
      "fcmToken": fcmToken,
      "platform": platform,
    });
  }

  Future<void> unregisterFcmToken({required String fcmToken}) async {
    await api.post(ApiEndpoints.unregisterFcmToken, {"fcmToken": fcmToken});
  }
}
