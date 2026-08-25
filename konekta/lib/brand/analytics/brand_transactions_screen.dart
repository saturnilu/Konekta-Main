import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../data/repositories/dashboard_repository.dart';

class BrandTransactionsScreen extends StatefulWidget {
  const BrandTransactionsScreen({super.key});

  @override
  State<BrandTransactionsScreen> createState() => _BrandTransactionsScreenState();
}

class _BrandTransactionsScreenState extends State<BrandTransactionsScreen> {
  final List<BrandTransaction> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;
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
      final result = await DashboardRepository(scope.api).brandTransactions(page: 1);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final scope = AppScope.of(context);
      final result = await DashboardRepository(scope.api).brandTransactions(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
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

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final datePart = iso.split(' ').first;
    final parts = datePart.split('-');
    if (parts.length != 3) return datePart;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${parts[2]} ${months[m]} ${parts[0]}';
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
              ? _ErrorState(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) _loadMore();
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            final t = _items[i];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: KonektaColors.success.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_upward_rounded, color: KonektaColors.success, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.influencerName ?? 'Creator',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: KonektaColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          t.campaignTitle ?? t.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: KonektaColors.textSecondary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(t.createdAt),
                                          style: const TextStyle(fontSize: 11, color: KonektaColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '- Rp ${_formatRupiah(t.amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: KonektaColors.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 12),
            Text('No transactions yet', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text(
              'Payments you make to creators will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}