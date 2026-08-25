import '../../core/api_client.dart';

class PaymentMethod {
  final int id;
  final String type;
  final String label;
  final String? provider;
  final String? last4;
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    this.provider,
    this.last4,
    this.isDefault = false,
  });

  String get displaySubtitle {
    final parts = <String>[];
    if (provider != null && provider!.isNotEmpty) parts.add(provider!);
    if (last4 != null && last4!.isNotEmpty) parts.add('•••• $last4');
    return parts.join(' ');
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return PaymentMethod(
      id: i(json['id']),
      type: (json['type'] ?? 'bank_transfer').toString(),
      label: (json['label'] ?? '').toString(),
      provider: json['provider']?.toString(),
      last4: json['last4']?.toString(),
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }
}

class PaymentMethodRepository {
  final ApiClient api;
  PaymentMethodRepository(this.api);

  Future<List<PaymentMethod>> mine() async {
    final data = await api.get('/payment-methods/mine');
    return (data as List).map((e) => PaymentMethod.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<PaymentMethod> add({
    required String type,
    required String label,
    String? provider,
    String? last4,
    bool isDefault = false,
  }) async {
    final data = await api.post('/payment-methods', {
      'type': type,
      'label': label,
      if (provider != null) 'provider': provider,
      if (last4 != null) 'last4': last4,
      'is_default': isDefault,
    });
    return PaymentMethod.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> remove(int id) async {
    await api.delete('/payment-methods/$id');
  }

  Future<void> setDefault(int id) async {
    await api.post('/payment-methods/$id/default', const {});
  }
}