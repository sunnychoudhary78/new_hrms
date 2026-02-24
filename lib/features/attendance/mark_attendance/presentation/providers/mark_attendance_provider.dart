import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/core/providers/location_providers.dart';
import 'package:lms/core/services/location_service.dart';
import 'package:lms/core/services/selfie_service.dart';
import 'package:lms/features/attendance/shared/data/attendance_repository_provider.dart';
import 'package:lms/features/attendance/shared/data/attendance_rerpository.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';

final markAttendanceProvider =
    AsyncNotifierProvider<MarkAttendanceNotifier, List<AttendanceSession>>(
      MarkAttendanceNotifier.new,
    );

class MarkAttendanceNotifier extends AsyncNotifier<List<AttendanceSession>> {
  late AttendanceRepository _repo;
  late LocationService _locationService;
  late SelfieService _selfieService;

  @override
  Future<List<AttendanceSession>> build() async {
    _repo = ref.read(attendanceRepositoryProvider);
    _locationService = ref.read(locationServiceProvider);
    _selfieService = SelfieService();

    return _loadToday();
  }

  // ─────────────────────────────────────────────
  // LOAD TODAY
  // ─────────────────────────────────────────────

  Future<List<AttendanceSession>> _loadToday() async {
    final now = DateTime.now();

    final res = await _repo.fetchAttendance(month: now.month, year: now.year);

    return res.sessions;
  }

  Future<void> refresh() async {
    try {
      final fresh = await _loadToday();
      state = AsyncData(fresh);
    } catch (_) {
      // preserve current state, do nothing
    }
  }

  // ─────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _getUserLocation() async {
    final ready = await _locationService.ensureServiceAndPermission();

    if (!ready) {
      throw Exception("Location not available");
    }

    final pos = await _locationService.getCurrentLocation();

    if (pos == null) {
      throw Exception("Unable to fetch location");
    }

    return {
      "lat": pos.latitude,
      "lng": pos.longitude,
      "accuracy": pos.accuracy,
    };
  }

  // ─────────────────────────────────────────────
  // CORE HANDLER (INDUSTRY STANDARD)
  // ─────────────────────────────────────────────

  Future<void> _handleAttendance({
    required BuildContext context,
    required bool isCheckIn,
    required bool isRemote,
    String? remoteReason,
  }) async {
    final loader = ref.read(globalLoadingProvider.notifier);

    // Prevent duplicate taps
    if (ref.read(globalLoadingProvider).isLoading) {
      return;
    }

    try {
      // ─────────────────────────────────────────────
      // STEP 1: FETCH MOBILE CONFIG
      // ─────────────────────────────────────────────

      loader.showLoading("Checking requirements...");

      final config = await _repo.fetchMobileConfig();

      // Block if mobile attendance disabled
      if (!config.allowMobileCheckin) {
        loader.showError(
          isCheckIn
              ? "Mobile check-in is not allowed."
              : "Mobile check-out is not allowed.",
        );

        return;
      }

      // Decide requirements dynamically
      final bool requireSelfie = isCheckIn
          ? config.requireMobileCheckinSelfie
          : config.requireMobileCheckoutSelfie;

      final bool requireGPS = config.requireMobileGps;

      File? compressedFile;
      Map<String, dynamic>? location;

      // ─────────────────────────────────────────────
      // STEP 2: CAPTURE SELFIE IF REQUIRED
      // ─────────────────────────────────────────────

      if (requireSelfie) {
        loader.update(
          isCheckIn
              ? "Capturing check-in selfie..."
              : "Capturing check-out selfie...",
        );

        final selfieFile = await _selfieService.captureSelfie(context);

        if (selfieFile == null) {
          throw Exception("Selfie is required");
        }

        loader.update("Compressing image...");

        compressedFile = await _selfieService.compressImage(selfieFile);

        final sizeKb = await compressedFile.length() / 1024;

        if (sizeKb > 5000) {
          throw Exception("Image must be less than 5MB");
        }
      }

      // ─────────────────────────────────────────────
      // STEP 3: FETCH GPS IF REQUIRED
      // ─────────────────────────────────────────────

      if (requireGPS) {
        loader.update("Fetching location...");

        location = await _getUserLocation();
      }

      // ─────────────────────────────────────────────
      // STEP 4: BUILD REQUEST BODY
      // ─────────────────────────────────────────────

      final body = <String, dynamic>{
        "source": "mobile", // ALWAYS mobile per backend docs
      };

      if (location != null) {
        body["location"] = location;
      }

      if (isRemote) {
        body["remoteRequested"] = true;

        if (remoteReason != null && remoteReason.isNotEmpty) {
          body["remoteReason"] = remoteReason;
        }
      }

      // ─────────────────────────────────────────────
      // STEP 5: SEND API REQUEST
      // ─────────────────────────────────────────────

      loader.update(isCheckIn ? "Marking check-in..." : "Marking check-out...");

      if (isCheckIn) {
        await _repo.punchInMultipart(file: compressedFile, body: body);
      } else {
        await _repo.punchOutMultipart(file: compressedFile, body: body);
      }

      // ─────────────────────────────────────────────
      // STEP 6: REFRESH STATE
      // ─────────────────────────────────────────────

      loader.update("Refreshing attendance...");

      await refresh();

      loader.showSuccess(
        isCheckIn
            ? (isRemote ? "Remote check-in successful" : "Check-in successful")
            : (isRemote
                  ? "Remote check-out successful"
                  : "Check-out successful"),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      loader.showError(e.toString());
    }
  }

  // ─────────────────────────────────────────────
  // PUBLIC METHODS
  // ─────────────────────────────────────────────

  /// Mobile Check-In
  Future<void> punchIn(BuildContext context) async {
    await _handleAttendance(context: context, isCheckIn: true, isRemote: false);
  }

  /// Mobile Check-Out
  Future<void> punchOut(BuildContext context) async {
    await _handleAttendance(
      context: context,
      isCheckIn: false,
      isRemote: false,
    );
  }

  /// Remote Check-In
  Future<void> punchInRemote(BuildContext context, String reason) async {
    await _handleAttendance(
      context: context,
      isCheckIn: true,
      isRemote: true,
      remoteReason: reason,
    );
  }

  /// Remote Check-Out
  Future<void> punchOutRemote(BuildContext context, String reason) async {
    await _handleAttendance(
      context: context,
      isCheckIn: false,
      isRemote: true,
      remoteReason: reason,
    );
  }
}
