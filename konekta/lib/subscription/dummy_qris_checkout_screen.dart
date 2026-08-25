import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../data/models/subscription.dart' as model;
import 'subscription_cubit.dart';
import 'subscription_success_dialog.dart';

String _formatRupiah(num value) {
  final digits = value.round().toString();
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

class DummyQrisCheckoutScreen extends StatefulWidget {
  final model.SubscriptionPlan plan;
  const DummyQrisCheckoutScreen({super.key, required this.plan});

  @override
  State<DummyQrisCheckoutScreen> createState() => _DummyQrisCheckoutScreenState();
}

class _DummyQrisCheckoutScreenState extends State<DummyQrisCheckoutScreen> {
  late final String _fakeQrPayload;
  late final String _fakeInvoiceId;
  Duration _remaining = const Duration(minutes: 15);
  Timer? _timer;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _fakeQrPayload = _generateFakeQrisPayload();
    _fakeInvoiceId = 'DUMMY-${DateTime.now().millisecondsSinceEpoch}';
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds <= 1) {
          _timer?.cancel();
          _remaining = Duration.zero;
        } else {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  String _generateFakeQrisPayload() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomTail = List.generate(24, (_) => chars[rand.nextInt(chars.length)]).join();
    final amount = (widget.plan.price ?? 0).toStringAsFixed(0);
    return '00020101021226670016ID.CO.QRIS.WWW0215ID.KONEKTA.DUMMY${amount.padLeft(10, '0')}$randomTail';
  }

  Future<void> _simulatePaymentSuccess() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final updated = await context.read<SubscriptionCubit>().subscribe(widget.plan.id);
      if (!mounted) return;
      await showSubscriptionSuccessDialog(context, updated);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtTimer(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.plan.price ?? 0;
    final expired = _remaining == Duration.zero;

    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan to Pay', style: TextStyle(color: KonektaColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KonektaColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KonektaColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_outlined, color: KonektaColors.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demo mode: this QR is a placeholder and cannot be scanned by a real bank/e-wallet app. No real payment gateway is connected yet.',
                        style: TextStyle(fontSize: 12, color: KonektaColors.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('QRIS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: KonektaColors.textPrimary, letterSpacing: 1)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: KonektaColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                          child: const Text('DEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: KonektaColors.success)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Konekta • ${widget.plan.name} Plan', style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary)),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: expired ? 0.25 : 1,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: KonektaColors.border), borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(
                          data: _fakeQrPayload,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (expired)
                      const Text('QR expired', style: TextStyle(color: KonektaColors.danger, fontWeight: FontWeight.bold))
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: KonektaColors.textSecondary),
                          const SizedBox(width: 6),
                          Text('Expires in ${_fmtTimer(_remaining)}', style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary)),
                        ],
                      ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _row('Invoice', _fakeInvoiceId),
                    const SizedBox(height: 8),
                    _row('Amount', 'Rp ${_formatRupiah(price)}'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_confirming || expired) ? null : _simulatePaymentSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KonektaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _confirming
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("I've paid (simulate)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'In production this button is replaced by real-time payment confirmation from the gateway.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: KonektaColors.textMuted.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KonektaColors.textPrimary)),
      ],
    );
  }
}