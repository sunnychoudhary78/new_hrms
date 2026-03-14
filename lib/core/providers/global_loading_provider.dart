import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overlay states
enum GlobalOverlayState { idle, loading, success, error, message }

/// Immutable state
class GlobalLoadingState {
  final GlobalOverlayState state;
  final String message;

  const GlobalLoadingState({required this.state, required this.message});

  /// Idle state
  const GlobalLoadingState.idle()
    : state = GlobalOverlayState.idle,
      message = '';

  bool get isLoading => state == GlobalOverlayState.loading;
  bool get isSuccess => state == GlobalOverlayState.success;
  bool get isError => state == GlobalOverlayState.error;
  bool get isMessage => state == GlobalOverlayState.message;
  bool get isVisible => state != GlobalOverlayState.idle;

  GlobalLoadingState copyWith({GlobalOverlayState? state, String? message}) {
    return GlobalLoadingState(
      state: state ?? this.state,
      message: message ?? this.message,
    );
  }
}

/// Global Loader Notifier
class GlobalLoadingNotifier extends Notifier<GlobalLoadingState> {
  Timer? _timer;

  @override
  GlobalLoadingState build() {
    return const GlobalLoadingState.idle();
  }

  /// ───────────────── LOADING ─────────────────

  void showLoading([String message = "Please wait..."]) {
    _cancelTimer();

    print("🟡 GLOBAL LOADING: $message");

    state = GlobalLoadingState(
      state: GlobalOverlayState.loading,
      message: message,
    );
  }

  /// ───────────────── SUCCESS ─────────────────

  void showSuccess(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _cancelTimer();

    print("🟢 GLOBAL SUCCESS: $message");

    state = GlobalLoadingState(
      state: GlobalOverlayState.success,
      message: message,
    );

    _timer = Timer(duration, _hideInternal);
  }

  /// ───────────────── ERROR ─────────────────

  void showError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _cancelTimer();

    print("🔴 GLOBAL ERROR: $message");

    state = GlobalLoadingState(
      state: GlobalOverlayState.error,
      message: message,
    );

    _timer = Timer(duration, _hideInternal);
  }

  /// ───────────────── MESSAGE ─────────────────

  void showMessage(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _cancelTimer();

    print("🔵 GLOBAL MESSAGE: $message");

    state = GlobalLoadingState(
      state: GlobalOverlayState.message,
      message: message,
    );

    _timer = Timer(duration, _hideInternal);
  }

  /// ───────────────── API HELPERS ─────────────────

  void showApiError(Object e) {
    final msg = e
        .toString()
        .replaceFirst("Exception: ", "")
        .replaceAll("\n", " ")
        .trim();

    showError(msg.isEmpty ? "Something went wrong" : msg);
  }

  void showApiSuccess(String message) {
    showSuccess(message);
  }

  /// ───────────────── UPDATE MESSAGE ─────────────────

  void update(String message) {
    if (state.state == GlobalOverlayState.loading) {
      state = state.copyWith(message: message);
    }
  }

  /// ───────────────── RESET / HIDE ─────────────────

  /// Fully reset overlay
  void reset() {
    _cancelTimer();

    print("🧹 GLOBAL OVERLAY RESET");

    state = const GlobalLoadingState.idle();
  }

  /// Hide overlay manually
  void hide() {
    _cancelTimer();
    _hideInternal();
  }

  /// Internal hide
  void _hideInternal() {
    state = const GlobalLoadingState.idle();
  }

  /// Cancel any active timers
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provider
final globalLoadingProvider =
    NotifierProvider<GlobalLoadingNotifier, GlobalLoadingState>(
      GlobalLoadingNotifier.new,
    );
