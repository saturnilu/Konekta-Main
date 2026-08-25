import '../../core/api_client.dart';
import '../models/subscription.dart';

class SubscriptionRepository {
  final ApiClient api;
  SubscriptionRepository(this.api);

  Future<List<SubscriptionPlan>> listPlans() async {
    final res = await api.get('/subscriptions/plans');
    if (res == null) return const [];
    final raw = (res is List)
        ? res
        : ((res as Map)['items'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => SubscriptionPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Subscription?> current() async {
    try {
      final res = await api.get('/subscriptions/me');
      if (res == null) return null;
      final map = (res is Map) ? Map<String, dynamic>.from(res) : null;
      if (map == null) return null;
      return Subscription.fromJson(map);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Subscription> subscribe(int planId) async {
    final res = await api.post('/subscriptions/subscribe', {'plan_id': planId});
    return Subscription.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Subscription> cancel() async {
    final res = await api.post('/subscriptions/cancel', const {});
    return Subscription.fromJson(Map<String, dynamic>.from(res as Map));
  }
}