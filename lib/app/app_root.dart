import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_actions_provider.dart';
import 'package:lms/core/screens/subscribtion_expired_screen.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';

import '../core/notifications/notification_action.dart';
import '../core/notifications/notification_router.dart';
import '../core/notifications/notification_action_notifier.dart';
import '../core/providers/notification_api_providers.dart';

import '../core/providers/global_loading_provider.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _pushInitialized = false;
  bool _autoLoginAttempted = false;

  late final ProviderSubscription<NotificationAction?> _notificationSub;
  late final ProviderSubscription<GlobalAction?> _globalActionSub;

  @override
  void initState() {
    super.initState();

    /// AUTO LOGIN
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoLoginAttempted) return;

      _autoLoginAttempted = true;

      final auth = ref.read(authProvider);

      if (!auth.isSubscriptionExpired) {
        ref.read(authProvider.notifier).tryAutoLogin();
      }
    });

    /// 🔔 Notification action listener
    _notificationSub = ref.listenManual<NotificationAction?>(
      notificationActionProvider,
      (previous, next) {
        if (next != null && mounted) {
          _handleNotificationAction(next);
          ref.read(notificationActionProvider.notifier).clear();
        }
      },
    );

    /// 🌍 GLOBAL ACTION LISTENER
    _globalActionSub = ref.listenManual<GlobalAction?>(globalActionProvider, (
      previous,
      next,
    ) {
      if (next == null) return;

      final overlay = ref.read(globalLoadingProvider.notifier);

      switch (next.type) {
        case GlobalActionType.loading:
          overlay.showLoading(next.message);
          break;

        case GlobalActionType.success:
          overlay.showSuccess(next.message);
          break;

        case GlobalActionType.error:
          overlay.showError(next.message);
          break;
      }

      ref.read(globalActionProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _notificationSub.close();
    _globalActionSub.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    /// 🔄 Loading state
    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    /// 🔒 Global subscription lock
    if (authState.isSubscriptionExpired) {
      return const SubscriptionExpiredScreen();
    }

    /// 🔐 Not logged in
    if (authState.profile == null) {
      return const LoginScreen();
    }

    /// 🚀 Logged in
    _initPushIfNeeded();

    return const HomeScreen();
  }

  /// ─────────────────────────────────────────────
  /// 🔔 PUSH INIT (only after login)
  /// ─────────────────────────────────────────────
  void _initPushIfNeeded() {
    if (_pushInitialized) return;

    _pushInitialized = true;

    final pushService = ref.read(pushNotificationServiceProvider);

    pushService.init(
      onNotificationTap: (data) {
        final action = NotificationRouter.resolve(
          type: data['type'] as String?,
          data: data,
        );

        ref.read(notificationActionProvider.notifier).emit(action);
      },

      /// Refresh notifications if received in foreground
      onForegroundNotification: () {
        ref.read(notificationProvider.notifier).refresh();
      },

      /// Register token if logged in
      onTokenAvailable: (token) {
        final authState = ref.read(authProvider);

        if (authState.profile != null) {
          ref.read(authProvider.notifier).registerFcmTokenIfNeeded();
        }
      },
    );
  }

  /// ─────────────────────────────────────────────
  /// 🧭 Notification navigation
  /// ─────────────────────────────────────────────
  void _handleNotificationAction(NotificationAction action) {
    final nav = Navigator.of(context);

    switch (action) {
      case OpenLeaveStatus():
        nav.pushNamed(
          '/leave-status',
          arguments: {'highlightId': action.leaveRequestId},
        );
        break;

      case OpenLeaveApproval():
        nav.pushNamed(
          '/leave-approve',
          arguments: {'leaveRequestId': action.leaveRequestId},
        );
        break;

      case OpenAttendance():
        nav.pushNamed('/mark-attendance', arguments: {'date': action.date});
        break;

      case OpenAttendanceCorrection():
        nav.pushNamed(
          '/correct-attendance',
          arguments: {'correctionId': action.correctionId},
        );
        break;

      case OpenNotifications():
        nav.pushNamed('/notifications');
        break;

      case NoAction():
        break;
    }
  }
}
