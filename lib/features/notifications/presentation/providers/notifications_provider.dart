import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/notification_api_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';

/// 🔔 Main Notification Provider
final notificationProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationNotifier,
      List<Map<String, dynamic>>
    >(NotificationNotifier.new);

class NotificationNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final auth = ref.watch(authProvider);

    /// ⛔ STOP provider until login finishes
    if (auth.profile == null) {
      throw Exception("User not logged in yet");
    }

    final api = ref.read(notificationApiServiceProvider);
    return api.fetchMyNotifications();
  }

  /// 🔄 Manual refresh
  Future<void> refresh() async {
    state = const AsyncLoading();

    try {
      final api = ref.read(notificationApiServiceProvider);
      final data = await api.fetchMyNotifications();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// ✅ Mark single notification as read (Optimistic update)
  Future<void> markAsRead(String id) async {
    final api = ref.read(notificationApiServiceProvider);

    final currentList = state.value ?? [];

    // 1️⃣ Optimistic update
    state = AsyncData([
      for (final n in currentList)
        if (n['id'] == id) {...n, 'is_read': true} else n,
    ]);

    try {
      // 2️⃣ Backend call
      await api.markAsRead(id);
    } catch (e) {
      // 3️⃣ Rollback if failed
      state = AsyncData(currentList);
      rethrow;
    }
  }

  /// 🗑️ Delete single notification (Optimistic update)
  Future<void> deleteNotification(String id) async {
    final api = ref.read(notificationApiServiceProvider);

    final currentList = state.value ?? [];

    // 1️⃣ Optimistic update (remove immediately from UI)
    state = AsyncData(currentList.where((n) => n['id'] != id).toList());

    try {
      // 2️⃣ Backend call
      await api.deleteNotifications([id]);
    } catch (e) {
      // 3️⃣ Rollback if failed
      state = AsyncData(currentList);
      rethrow;
    }
  }

  /// 🗑️ Delete multiple notifications
  Future<void> deleteMultipleNotifications(List<String> ids) async {
    final api = ref.read(notificationApiServiceProvider);

    final currentList = state.value ?? [];

    // Optimistic update
    state = AsyncData(
      currentList.where((n) => !ids.contains(n['id'])).toList(),
    );

    try {
      await api.deleteNotifications(ids);
    } catch (e) {
      state = AsyncData(currentList);
      rethrow;
    }
  }
}

/// 🔴 Unread Count Provider (Derived)
final unreadCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationProvider);

  return notificationsAsync.maybeWhen(
    data: (list) => list.where((n) => n['is_read'] == false).length,
    orElse: () => 0,
  );
});
