import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../data/repositories/withdrawal_repository.dart';
import 'withdrawal_cubit.dart';

class WithdrawEarningsScreen extends StatelessWidget {
  const WithdrawEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider(
      create: (_) => WithdrawalCubit(WithdrawalRepository(scope.api))..load(),
      child: const _WithdrawEarningsView(),
    );
  }
}

class _WithdrawEarningsView extends StatefulWidget {
  const _WithdrawEarningsView();

  @override
  State<_WithdrawEarningsView> createState() => _WithdrawEarningsViewState();
}

class _WithdrawEarningsViewState extends State<_WithdrawEarningsView> {
  final _amountCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final amount = num.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (_bankCtrl.text.trim().isEmpty || _accountNumberCtrl.text.trim().isEmpty || _accountNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill in all bank details')));
      return;
    }

    try {
      await context.read<WithdrawalCubit>().submit(
            amount: amount,
            bankName: _bankCtrl.text.trim(),
            accountNumber: _accountNumberCtrl.text.trim(),
            accountName: _accountNameCtrl.text.trim(),
          );
      if (!mounted) return;
      _amountCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submitted — usually processed within 1-3 business days')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return KonektaColors.success;
      case 'rejected': return KonektaColors.danger;
      case 'processing': return KonektaColors.primary;
      default: return KonektaColors.warning; // pending
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WithdrawalCubit, WithdrawalState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: KonektaColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('Withdraw Earnings', style: TextStyle(color: KonektaColors.textPrimary, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
          ),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                  ? Center(child: Text(state.error!, style: const TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: () => context.read<WithdrawalCubit>().load(),
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildBalanceCard(state.balance),
                          const SizedBox(height: 24),
                          _buildRequestForm(state),
                          const SizedBox(height: 28),
                          const Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KonektaColors.textPrimary)),
                          const SizedBox(height: 12),
                          if (state.history.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('No withdrawal requests yet', style: TextStyle(color: Colors.grey))),
                            )
                          else
                            ...state.history.map(_buildHistoryRow),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildBalanceCard(WithdrawalBalance? b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF4FB6FF), Color(0xFF1F6FE5)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            'Rp ${_formatRupiah(b?.available ?? 0)}',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniStat('Total earned', 'Rp ${_formatRupiah(b?.totalEarned ?? 0)}')),
              Expanded(child: _miniStat('Withdrawn', 'Rp ${_formatRupiah(b?.totalWithdrawn ?? 0)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildRequestForm(WithdrawalState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: KonektaColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: KonektaColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requests are reviewed manually and typically arrive within 1-3 business days. Minimum withdrawal: Rp ${_formatRupiah(state.balance?.minWithdrawal ?? 50000)}.',
                    style: const TextStyle(fontSize: 11, color: KonektaColors.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: 'Rp ', hintText: '100000'),
          ),
          const SizedBox(height: 14),
          const Text('Bank name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: _bankCtrl, decoration: const InputDecoration(hintText: 'e.g. BCA, Mandiri, BRI')),
          const SizedBox(height: 14),
          const Text('Account number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: _accountNumberCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '1234567890')),
          const SizedBox(height: 14),
          const Text('Account holder name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: _accountNameCtrl, decoration: const InputDecoration(hintText: 'As it appears on your bank account')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: state.submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: KonektaColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state.submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Request withdrawal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(WithdrawalRequest w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rp ${_formatRupiah(w.amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${w.bankName} • ${w.accountNumber}', style: const TextStyle(fontSize: 12, color: KonektaColors.textSecondary)),
                if (w.requestedAt != null)
                  Text(w.requestedAt!.split(' ').first, style: const TextStyle(fontSize: 11, color: KonektaColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(w.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              w.status.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(w.status)),
            ),
          ),
        ],
      ),
    );
  }
}