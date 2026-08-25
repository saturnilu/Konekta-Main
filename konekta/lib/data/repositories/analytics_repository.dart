import '../../core/api_client.dart';

class AnalyticsRepository {
  final ApiClient api;
  AnalyticsRepository(this.api);

  Future<Map<String, dynamic>> influencerAnalytics({required int days}) async {
    final result = await api.get('/analytics/influencer', query: {'days': days});
    return result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> brandAnalytics({required int days}) async {
    final result = await api.get('/analytics/brand', query: {'days': days});
    return result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
  }
}