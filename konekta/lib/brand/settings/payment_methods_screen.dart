import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../data/repositories/payment_method_repository.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _loading = true;
  String? _error;
  List<PaymentMethod> _methods = [];
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
      final list = await PaymentMethodRepository(scope.api).mine();
      if (!mounted) return;
      setState(() { _methods = list; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _delete(PaymentMethod m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this payment method?'),
        content: Text('${m.label}${m.displaySubtitle.isNotEmpty ? " (${m.displaySubtitle})" : ""} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: KonektaColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final scope = AppScope.of(context);
    try {
      await scope.run(() => PaymentMethodRepository(scope.api).remove(m.id));
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment method removed')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _setDefault(PaymentMethod m) async {
    if (m.isDefault) return;
    final scope = AppScope.of(context);
    try {
      await scope.run(() => PaymentMethodRepository(scope.api).setDefault(m.id));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddPaymentMethodSheet(),
    );
    if (result == true) _load();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'card': return Icons.credit_card_rounded;
      case 'e_wallet': return Icons.account_balance_wallet_rounded;
      default: return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Payment Methods', style: TextStyle(color: KonektaColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: KonektaColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KonektaColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: KonektaColors.warning, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Demo mode: only a label and last 4 digits are saved — never your full card number.',
                                style: TextStyle(fontSize: 11, color: KonektaColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_methods.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.credit_card_off_outlined, size: 40, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('No payment methods saved yet', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap + to add one so you don\'t have to re-enter it every time you pay a creator.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._methods.map((m) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: m.isDefault ? Border.all(color: KonektaColors.primary, width: 1.5) : null,
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(color: KonektaColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: Icon(_iconFor(m.type), color: KonektaColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                            if (m.isDefault) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: KonektaColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                                child: const Text('DEFAULT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: KonektaColors.primary)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (m.displaySubtitle.isNotEmpty)
                                          Text(m.displaySubtitle, style: const TextStyle(fontSize: 12, color: KonektaColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  if (!m.isDefault)
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: KonektaColors.textSecondary),
                                      tooltip: 'Set as default',
                                      onPressed: () => _setDefault(m),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: KonektaColors.danger),
                                    tooltip: 'Remove',
                                    onPressed: () => _delete(m),
                                  ),
                                ],
                              ),
                            )),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }
}

class _AddPaymentMethodSheet extends StatefulWidget {
  const _AddPaymentMethodSheet();

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  String _type = 'bank_transfer';
  final _labelCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    if (_labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give this method a name, e.g. "Company BCA"')));
      return;
    }
    if (_last4Ctrl.text.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(_last4Ctrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Last 4 digits must be exactly 4 numbers')));
      return;
    }
    setState(() => _saving = true);
    final scope = AppScope.of(context);
    try {
      await scope.run(() => PaymentMethodRepository(scope.api).add(
            type: _type,
            label: _labelCtrl.text.trim(),
            provider: _providerCtrl.text.trim().isEmpty ? null : _providerCtrl.text.trim(),
            last4: _last4Ctrl.text.trim().isEmpty ? null : _last4Ctrl.text.trim(),
          ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _providerCtrl.dispose();
    _last4Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add payment method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _typeChip('bank_transfer', 'Bank Transfer'),
                  _typeChip('card', 'Card'),
                  _typeChip('e_wallet', 'E-Wallet'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(controller: _labelCtrl, decoration: const InputDecoration(hintText: 'e.g. Company BCA Account')),
              const SizedBox(height: 12),
              const Text('Bank / provider (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(controller: _providerCtrl, decoration: const InputDecoration(hintText: 'e.g. BCA, Mandiri, GoPay')),
              const SizedBox(height: 12),
              const Text('Last 4 digits (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _last4Ctrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(hintText: '1234', counterText: ''),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KonektaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _type == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _type = value),
      selectedColor: KonektaColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: selected ? KonektaColors.primary : KonektaColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
      side: BorderSide(color: selected ? KonektaColors.primary : KonektaColors.border),
    );
  }
}