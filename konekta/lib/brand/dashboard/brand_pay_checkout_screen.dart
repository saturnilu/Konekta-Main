import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../data/repositories/payment_method_repository.dart';
import '../settings/payment_methods_screen.dart';

class BrandPayCheckoutScreen extends StatefulWidget {
  final String influencerName;
  final num amount;
  final String? payoutBank;
  final String? payoutAccount;
  final Future<void> Function() onConfirm;

  const BrandPayCheckoutScreen({
    super.key,
    required this.influencerName,
    required this.amount,
    required this.payoutBank,
    required this.payoutAccount,
    required this.onConfirm,
  });

  @override
  State<BrandPayCheckoutScreen> createState() => _BrandPayCheckoutScreenState();
}

class _BrandPayCheckoutScreenState extends State<BrandPayCheckoutScreen> {
  String _method = 'bank_transfer';
  bool _paying = false;
  List<PaymentMethod> _savedMethods = [];
  int? _selectedSavedId;
  bool _loadingMethods = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadSavedMethods();
    }
  }

  Future<void> _loadSavedMethods() async {
    try {
      final scope = AppScope.of(context);
      final methods = await PaymentMethodRepository(scope.api).mine();
      if (!mounted) return;
      setState(() {
        _savedMethods = methods;
        _selectedSavedId = methods.isNotEmpty
            ? methods.firstWhere((m) => m.isDefault, orElse: () => methods.first).id
            : null;
        _loadingMethods = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMethods = false);
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

  bool get _hasBankDetails => (widget.payoutBank ?? '').isNotEmpty && (widget.payoutAccount ?? '').isNotEmpty;

  Future<void> _confirmTransfer() async {
    setState(() => _paying = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: KonektaColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: KonektaColors.success, size: 42),
                ),
                const SizedBox(height: 14),
                const Text('Payment Sent', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Rp ${_formatRupiah(widget.amount)} to ${widget.influencerName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KonektaColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pay Creator', style: TextStyle(color: KonektaColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KonektaColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_outlined, color: KonektaColors.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demo mode — no real bank transfer or payment gateway happens here yet.',
                        style: TextStyle(fontSize: 11, color: KonektaColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Amount', style: TextStyle(fontSize: 13, color: KonektaColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Rp ${_formatRupiah(widget.amount)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: KonektaColors.textPrimary)),
              const SizedBox(height: 24),
              const Text('Sending to', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KonektaColors.textPrimary)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: _hasBankDetails
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.influencerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('${widget.payoutBank} • ${widget.payoutAccount}', style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary)),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: KonektaColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.influencerName} hasn\'t added their bank details yet — they\'ll need to before they can withdraw this payment.',
                              style: const TextStyle(fontSize: 12, color: KonektaColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KonektaColors.textPrimary)),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()),
                      );
                      _loadSavedMethods();
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    child: Text(_savedMethods.isEmpty ? '+ Add method' : 'Manage',
                        style: const TextStyle(fontSize: 12, color: KonektaColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingMethods)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_savedMethods.isNotEmpty)
                ..._savedMethods.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _savedMethodTile(m),
                    ))
              else ...[
                _methodTile('bank_transfer', 'Bank Transfer', Icons.account_balance_outlined),
                const SizedBox(height: 8),
                _methodTile('qris', 'QRIS', Icons.qr_code_2_rounded),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _paying ? null : _confirmTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KonektaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _paying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Confirm & Send Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedMethodTile(PaymentMethod m) {
    final selected = _selectedSavedId == m.id;
    return InkWell(
      onTap: () => setState(() => _selectedSavedId = m.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? KonektaColors.primary : KonektaColors.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              m.type == 'card' ? Icons.credit_card_rounded : (m.type == 'e_wallet' ? Icons.account_balance_wallet_rounded : Icons.account_balance_outlined),
              size: 20,
              color: selected ? KonektaColors.primary : KonektaColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (m.displaySubtitle.isNotEmpty)
                    Text(m.displaySubtitle, style: const TextStyle(fontSize: 11, color: KonektaColors.textMuted)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? KonektaColors.primary : KonektaColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTile(String value, String label, IconData icon) {
    final selected = _method == value;
    return InkWell(
      onTap: () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? KonektaColors.primary : KonektaColors.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? KonektaColors.primary : KonektaColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? KonektaColors.primary : KonektaColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}