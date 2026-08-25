import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/theme.dart';
import '../data/models/subscription.dart' as model;

Future<void> showSubscriptionSuccessDialog(BuildContext context, model.Subscription sub) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SubscriptionSuccessDialog(sub: sub),
  );
}

class _SubscriptionSuccessDialog extends StatefulWidget {
  final model.Subscription sub;
  const _SubscriptionSuccessDialog({required this.sub});

  @override
  State<_SubscriptionSuccessDialog> createState() => _SubscriptionSuccessDialogState();
}

class _SubscriptionSuccessDialogState extends State<_SubscriptionSuccessDialog> {
  bool _generating = false;

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
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> _downloadInvoice() async {
    setState(() => _generating = true);
    try {
      final doc = pw.Document();
      final sub = widget.sub;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Konekta', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Payment Invoice', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 12),
                _pdfRow('Invoice Number', sub.invoiceNumber ?? '-'),
                _pdfRow('Date', _formatDate(sub.startedAt)),
                _pdfRow('Plan', sub.planName ?? '-'),
                _pdfRow('Status', 'Paid (Demo)'),
                if (sub.expiresAt != null) _pdfRow('Valid until', _formatDate(sub.expiresAt)),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Paid', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rp ${_formatRupiah(sub.amount ?? 0)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Text(
                  'This is a demo invoice — no real payment gateway is connected yet. '
                  'It is generated locally for record-keeping purposes only.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ),
      );
      final bytes = await doc.save();
      await Printing.sharePdf(bytes: bytes, filename: '${widget.sub.invoiceNumber ?? "invoice"}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate invoice: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: KonektaColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: KonektaColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: KonektaColors.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KonektaColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              "You're now on the ${sub.planName ?? 'Pro'} plan",
              style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: KonektaColors.background, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  _row('Invoice No.', sub.invoiceNumber ?? '-'),
                  _row('Date', _formatDate(sub.startedAt)),
                  _row('Amount', 'Rp ${_formatRupiah(sub.amount ?? 0)}'),
                  if (sub.expiresAt != null) _row('Valid until', _formatDate(sub.expiresAt)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _generating ? null : _downloadInvoice,
                icon: _generating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_generating ? 'Preparing...' : 'Download Invoice'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: KonektaColors.primary),
                  foregroundColor: KonektaColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
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
    );
  }
}