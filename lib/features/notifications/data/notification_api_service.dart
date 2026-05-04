import '../../../core/network/api_service.dart';

class NotificationApiService {
  final ApiService api;

  NotificationApiService(this.api);

  // 📥 Fetch notifications
  Future<List<Map<String, dynamic>>> fetchMyNotifications() async {
    const pageSize = 100;
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await api.get(
        '/notifications/my',
        queryParams: {"page": page, "limit": pageSize},
      );

      if (response is List) {
        return response
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final data = response is Map ? response['data'] : null;
      if (data is List) {
        rows.addAll(
          data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }

      final meta = response is Map ? response['meta'] : null;
      if (meta is Map && meta['totalPages'] != null) {
        totalPages = int.tryParse(meta['totalPages'].toString()) ?? totalPages;
      } else {
        break;
      }

      page++;
    } while (page <= totalPages);

    return rows;
  }

  // ✅ Mark as read
  Future<void> markAsRead(String id) async {
    await api.patch('/notifications/$id/read', {});
  }

  // 🗑️ DELETE notifications (single or multiple)
  Future<void> deleteNotifications(List<String> ids) async {
    await api.delete('/notifications', {"ids": ids});
  }
}
