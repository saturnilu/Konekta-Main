import '../../core/api_client.dart';
import '../models/notification.dart';

class NotificationRepository {
  final ApiClient api;
  NotificationRepository(this.api);

  Future<List<AppNotification>> list() async {
    final data = await api.get('/notifications');
    final list = (data as List).cast<Map>();
    return list.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> markRead(int id) async {
    await api.post('/notifications/$id/read', {});
  }

  Future<void> markAllRead() async {
    await api.post('/notifications/read-all', {});
  }

  Future<int> unreadCount() async {
    final data = await api.get('/notifications/unread-count');
    final map = Map<String, dynamic>.from(data as Map);
    final c = map['count'];
    return c is num ? c.toInt() : int.tryParse('$c') ?? 0;
  }
}