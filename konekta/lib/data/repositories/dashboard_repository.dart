import '../../core/api_client.dart';
import '../models/influencer_summary.dart';

class BrandTransaction {
  final int id;
  final num amount;
  final String description;
  final String? createdAt;
  final int? offerId;
  final String? campaignTitle;
  final int? influencerId;
  final String? influencerName;
  final String? influencerUsername;

  BrandTransaction({
    required this.id,
    required this.amount,
    required this.description,
    this.createdAt,
    this.offerId,
    this.campaignTitle,
    this.influencerId,
    this.influencerName,
    this.influencerUsername,
  });

  factory BrandTransaction.fromJson(Map<String, dynamic> json) {
    num toNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    int? toInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
    return BrandTransaction(
      id: toInt(json['id']) ?? 0,
      amount: toNum(json['amount']),
      description: (json['description'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
      offerId: toInt(json['offer_id']),
      campaignTitle: json['campaign_title']?.toString(),
      influencerId: toInt(json['influencer_id']),
      influencerName: json['influencer_name']?.toString(),
      influencerUsername: json['influencer_username']?.toString(),
    );
  }
}

class BrandTransactionsPage {
  final int page;
  final int limit;
  final int total;
  final List<BrandTransaction> items;
  BrandTransactionsPage({required this.page, required this.limit, required this.total, required this.items});

  bool get hasMore => page * limit < total;
}

class BrandDashboardData {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rooms;
  BrandDashboardData({required this.summary, required this.rooms});
}

class DashboardRepository {
  final ApiClient api;
  DashboardRepository(this.api);

  Future<InfluencerSummary> influencerSummary() async {
    final data = await api.get('/dashboard/influencer');
    return InfluencerSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<BrandDashboardData> brandOverview() async {
    final summaryRaw = await api.get('/dashboard/brand');
    final offersRaw = await api.get('/offers/mine');
    final summaryMap = (summaryRaw is Map) ? Map<String, dynamic>.from(summaryRaw) : <String, dynamic>{};
    final summaryInner = (summaryMap['summary'] is Map)
        ? Map<String, dynamic>.from(summaryMap['summary'] as Map)
        : summaryMap;
    final rooms = (offersRaw is List) ? offersRaw : const [];
    return BrandDashboardData(
      summary: summaryInner,
      rooms: rooms.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  Future<BrandTransactionsPage> brandTransactions({int page = 1, int limit = 20}) async {
    final data = await api.get('/dashboard/brand/transactions', query: {'page': page, 'limit': limit});
    final map = Map<String, dynamic>.from(data as Map);
    final items = (map['items'] as List)
        .map((e) => BrandTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return BrandTransactionsPage(
      page: (map['page'] as num?)?.toInt() ?? page,
      limit: (map['limit'] as num?)?.toInt() ?? limit,
      total: (map['total'] as num?)?.toInt() ?? 0,
      items: items,
    );
  }
}