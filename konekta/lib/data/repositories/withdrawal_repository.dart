import '../../core/api_client.dart';

class WithdrawalBalance {
  final num totalEarned;
  final num totalWithdrawn;
  final num available;
  final num minWithdrawal;

  WithdrawalBalance({
    required this.totalEarned,
    required this.totalWithdrawn,
    required this.available,
    required this.minWithdrawal,
  });

  factory WithdrawalBalance.fromJson(Map<String, dynamic> json) {
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    return WithdrawalBalance(
      totalEarned: n(json['total_earned']),
      totalWithdrawn: n(json['total_withdrawn']),
      available: n(json['available']),
      minWithdrawal: n(json['min_withdrawal']),
    );
  }
}

class WithdrawalRequest {
  final int id;
  final num amount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String status;
  final String? notes;
  final String? requestedAt;
  final String? processedAt;

  WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.status,
    this.notes,
    this.requestedAt,
    this.processedAt,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    int i(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return WithdrawalRequest(
      id: i(json['id']),
      amount: n(json['amount']),
      bankName: (json['bank_name'] ?? '').toString(),
      accountNumber: (json['account_number'] ?? '').toString(),
      accountName: (json['account_name'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      notes: json['notes']?.toString(),
      requestedAt: json['requested_at']?.toString(),
      processedAt: json['processed_at']?.toString(),
    );
  }
}

class WithdrawalRepository {
  final ApiClient api;
  WithdrawalRepository(this.api);

  Future<WithdrawalBalance> balance() async {
    final data = await api.get('/withdrawals/balance');
    return WithdrawalBalance.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<WithdrawalRequest>> mine() async {
    final data = await api.get('/withdrawals/mine');
    return (data as List)
        .map((e) => WithdrawalRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<WithdrawalRequest> request({
    required num amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final data = await api.post('/withdrawals', {
      'amount': amount,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
    });
    return WithdrawalRequest.fromJson(Map<String, dynamic>.from(data as Map));
  }
}