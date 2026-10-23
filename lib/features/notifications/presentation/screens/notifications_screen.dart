import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:lms/features/notifications/presentation/widgets/notification_list.dart';
import 'package:lms/shared/widgets/app_bar.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(notificationProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notificationsAsync = ref.watch(notificationProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final listPhysics = isIOS
        ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
        : const AlwaysScrollableScrollPhysics();

    Future<void> onRefresh() async {
      await ref.read(notificationProvider.notifier).refresh();
    }

    Future<void> onMarkAllRead() async {
      if (unreadCount <= 0) return;
      try {
        await ref.read(notificationProvider.notifier).markAllAsRead();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark all as read')),
        );
      }
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Notifications',
        showBack: true,
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: unreadCount > 0 ? onMarkAllRead : null,
            icon: Icon(
              Icons.done_all_rounded,
              color: unreadCount > 0
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: listPhysics,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: Center(
                child: Text(
                  "Something went wrong\n$e",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ),
          ),
        ),
        data: (notifications) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: notifications.isEmpty
                ? ListView(
                    physics: listPhysics,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.55,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "You're all caught up",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : NotificationList(
                    notifications: notifications,
                    scrollPhysics: listPhysics,
                  ),
          );
        },
      ),
    );
  }
}
