import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../data/repositories/campaign_repository.dart';

class InfluencerAllApplicationsScreen extends StatefulWidget {
  const InfluencerAllApplicationsScreen({super.key});

  @override
  State<InfluencerAllApplicationsScreen> createState() => _InfluencerAllApplicationsScreenState();
}

class _InfluencerAllApplicationsScreenState extends State<InfluencerAllApplicationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final scope = AppScope.of(context);
      final items = await CampaignRepository(scope.api).myApplications();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  String _formatRupiah(num value) {
    final digits = value.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
        return KonektaColors.success;
      case 'rejected':
        return KonektaColors.danger;
      default:
        return KonektaColors.warning; // pending / shortlisted
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('All Transactions', style: TextStyle(color: KonektaColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('No applications yet', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          final status = (it['status'] ?? '-').toString();
                          final amount = it['proposed_rate'] ?? it['budget'] ?? 0;
                          final amountNum = amount is num ? amount : num.tryParse('$amount') ?? 0;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (it['title'] ?? 'Untitled').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: KonektaColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (it['brand_name'] ?? '').toString(),
                                        style: const TextStyle(fontSize: 12, color: KonektaColors.textSecondary),
                                      ),
                                      if (it['created_at'] != null)
                                        Text(
                                          it['created_at'].toString().split(' ').first,
                                          style: const TextStyle(fontSize: 11, color: KonektaColors.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Rp ${_formatRupiah(amountNum)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(status)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}