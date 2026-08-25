class SubscriptionPlan {
  final int id;
  final String name;
  final num? price;
  final String? currency;
  final int? durationMonths;
  final String? description;
  final List<String> features;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.price,
    this.currency,
    this.durationMonths,
    this.description,
    this.features = const [],
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    num? _n(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }
    return SubscriptionPlan(
      id: (json['plan_id'] is num ? (json['plan_id'] as num).toInt() : null) ??
          (json['id'] is num ? (json['id'] as num).toInt() : int.tryParse('${json['id'] ?? 0}') ?? 0),
      name: (json['plan_name'] ?? json['name'] ?? '') as String,
      price: _n(json['price'] ?? json['price_idr']),
      currency: (json['currency'] ?? 'IDR') as String?,
      durationMonths: (json['duration_months'] is num) ? (json['duration_months'] as num).toInt() : null,
      description: json['description'] as String?,
      features: ((json['features'] as List?)?.map((e) => e.toString()).toList()) ?? const [],
    );
  }
}

class Subscription {
  final int? id;
  final int? planId;
  final String? planName;
  final String? planCode;
  final String? status;
  final String? startedAt;
  final String? expiresAt;
  final bool autoRenew;
  final bool isActive;
  final num? amount;
  final String? invoiceNumber;

  Subscription({
    this.id,
    this.planId,
    this.planName,
    this.planCode,
    this.status,
    this.startedAt,
    this.expiresAt,
    this.autoRenew = false,
    this.isActive = false,
    this.amount,
    this.invoiceNumber,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final statusVal = (json['status'] ?? '').toString().toLowerCase();
    num? n(dynamic v) => v == null ? null : (v is num ? v : num.tryParse('$v'));
    return Subscription(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}'),
      planId: (json['plan_id'] is num) ? (json['plan_id'] as num).toInt() : int.tryParse('${json['plan_id']}'),
      planName: (json['plan_name'] ?? json['plan_code']) as String?,
      planCode: json['plan_code'] as String?,
      status: json['status'] as String?,
      startedAt: json['started_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      autoRenew: (json['auto_renew'] ?? false) == true,
      isActive: statusVal == 'active' || statusVal == 'trialing',
      amount: n(json['amount']),
      invoiceNumber: json['invoice_number'] as String?,
    );
  }
}