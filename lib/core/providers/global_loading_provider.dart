import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overlay states
enum GlobalOverlayState { idle, loading, success, error }

/// Immutable state
class GlobalLoadingState {
  final GlobalOverlayState state;
  final String message;

  const GlobalLoadingState({required this.state, required this.message});

  const GlobalLoadingState.idle()
    : state = GlobalOverlayState.idle,
      message = '';

  bool get isLoading => state == GlobalOverlayState.loading;

  bool get isSuccess => state == GlobalOverlayState.success;

  bool get isError => state == GlobalOverlayState.error;

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

  /// Show loading
  void showLoading([String message = "Please wait..."]) {
    _cancelTimer();

    state = GlobalLoadingState(
      state: GlobalOverlayState.loading,
      message: message,
    );
  }

  /// Show success
  void showSuccess(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _cancelTimer();

    state = GlobalLoadingState(
      state: GlobalOverlayState.success,
      message: message,
    );

    _timer = Timer(duration, _hideInternal);
  }

  /// Show error
  void showError(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _cancelTimer();

    state = GlobalLoadingState(
      state: GlobalOverlayState.error,
      message: message,
    );

    _timer = Timer(duration, _hideInternal);
  }

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

  /// Update message during loading
  void update(String message) {
    if (state.state == GlobalOverlayState.loading) {
      state = state.copyWith(message: message);
    }
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
