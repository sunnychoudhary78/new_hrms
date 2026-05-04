import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/screens/splash_loading_screen.dart';
import 'package:lms/core/screens/subscribtion_expired_screen.dart';
import 'package:lms/core/providers/user_data_invalidation.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';

import '../core/notifications/notification_action.dart';
import '../core/notifications/notification_router.dart';
import '../core/notifications/notification_action_notifier.dart';
import '../core/providers/notification_api_providers.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  static bool _hasShownStartupSplashInSession = false;

  bool _autoLoginAttempted = false;
  bool _pushInitialized = false;
  bool _minimumSplashElapsed = _hasShownStartupSplashInSession;
  bool _startupSplashCompleted = _hasShownStartupSplashInSession;

  String? _lastUserId;

  late final ProviderSubscription<NotificationAction?> _notificationSub;
  Timer? _minimumSplashTimer;
  Timer? _notificationSyncTimer; // 🔥 periodic sync

  @override
  void initState() {
    super.initState();

    if (!_hasShownStartupSplashInSession) {
      _minimumSplashTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _minimumSplashElapsed = true;
        });
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoLoginAttempted) return;

      _autoLoginAttempted = true;

      final auth = ref.read(authProvider);

      if (auth.isInitializing && !auth.isSubscriptionExpired) {
        ref.read(authProvider.notifier).tryAutoLogin();
      }

      _initPush();

      // 🔥 Periodic sync (prevents stale data)
      _notificationSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        ref.read(notificationProvider.notifier).refresh();
      });
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
  }

  @override
  void dispose() {
    _notificationSub.close();
    _minimumSplashTimer?.cancel();
    _notificationSyncTimer?.cancel(); // 🔥 cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.profile?.userId;

    /// 🔥 USER CHANGE DETECTED
    if (currentUserId != null && _lastUserId != currentUserId) {
      _lastUserId = currentUserId;

      invalidateAllUserScopedData(ref);

      _initPush(force: true);
    }

    final shouldShowStartupSplash =
        !_startupSplashCompleted &&
        (authState.isInitializing || !_minimumSplashElapsed);

    if (shouldShowStartupSplash) {
      return const SplashLoadingScreen();
    }

    if (!_startupSplashCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _startupSplashCompleted) return;
        setState(() {
          _startupSplashCompleted = true;
          _hasShownStartupSplashInSession = true;
        });
      });
    }

    if (authState.isSubscriptionExpired) {
      return const SubscriptionExpiredScreen();
    }

    if (authState.profile == null) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }

  /// ─────────────────────────────────────────────
  /// 🔔 PUSH INIT (FINAL STABLE)
  /// ─────────────────────────────────────────────
  void _initPush({bool force = false}) {
    if (_pushInitialized && !force) return;

    _pushInitialized = true;

    final pushService = ref.read(pushNotificationServiceProvider);

    pushService.init(
      onNotificationTap: (data) {
        final action = NotificationRouter.resolve(
          type: data['type'] as String?,
          data: data,
        );

        ref.read(notificationActionProvider.notifier).emit(action);

        // ✅ Safe refresh on tap
        ref.read(notificationProvider.notifier).refresh();
      },

      onForegroundNotification: (data) {
        final notifier = ref.read(notificationProvider.notifier);

        // ✅ ONLY local update (NO immediate refresh)
        notifier.addNotification({
          "id": data['id'] ?? DateTime.now().toString(),
          "is_read": false,
          ...data,
        });
      },

      onTokenAvailable: (token) async {
        print("🔥 FCM TOKEN: $token");

        final authState = ref.read(authProvider);

        if (authState.profile != null) {
          await ref.read(authProvider.notifier).registerFcmTokenIfNeeded();
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
        final permissions = ref.read(authProvider).permissions;
        if (permissions.contains('leave.request.approve')) {
          nav.pushNamed(
            '/leave-approve',
            arguments: {'leaveRequestId': action.leaveRequestId},
          );
        } else if (action.leaveRequestId.isNotEmpty) {
          nav.pushNamed(
            '/leave-status',
            arguments: {'highlightId': action.leaveRequestId},
          );
        } else {
          nav.pushNamed('/notifications');
        }
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

      case OpenExpenses():
        final permissions = ref.read(authProvider).permissions;
        final canOpenDashboard =
            action.preferDashboard &&
            (permissions.contains('expense.manager') ||
                permissions.contains('expense.hod') ||
                permissions.contains('expense.accounts'));

        nav.pushNamed(
          canOpenDashboard ? '/expenses-dashboard' : '/expenses/my',
        );
        break;

      case OpenResignation():
        final permissions = ref.read(authProvider).permissions;
        final canOpenDashboard =
            action.preferDashboard &&
            (permissions.contains('resignation.manager') ||
                permissions.contains('resignation.hod') ||
                permissions.contains('resignation.hr'));

        nav.pushNamed(
          canOpenDashboard ? '/resignation-dashboard' : '/resignation/my',
        );
        break;

      case OpenKra():
        nav.pushNamed('/kra');
        break;

      case OpenNotifications():
        nav.pushNamed('/notifications');
        break;

      case NoAction():
        break;
    }
  }
}
