import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faqs = [
    (
      'How do I apply to a campaign?',
      'Go to the Explore tab, open a campaign you like, and tap "Apply". The brand will review your application and approve or decline it.',
    ),
    (
      'When do I get paid for a campaign?',
      'Once a brand marks your submitted video as complete and pays out, the amount is added to your available balance. You can then request a withdrawal from the Withdraw Earnings screen.',
    ),
    (
      'How long does a withdrawal take?',
      'Withdrawal requests are currently reviewed manually and typically processed within 1-3 business days.',
    ),
    (
      'What does the Verified badge mean?',
      'The Verified Creator badge is included with the Pro plan. It shows up next to your name across the app while your Pro subscription is active.',
    ),
    (
      'Can I change my username?',
      'Yes — open your profile, tap Edit Profile, and update your username there.',
    ),
    (
      'How do I remove a linked social media account?',
      'On your profile, find the account under Social Accounts and tap the trash icon next to it.',
    ),
  ];

  Future<void> _emailSupport() async {
    final uri = Uri.parse('mailto:support@konekta.app?subject=Help%20with%20Konekta');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Help Center', style: TextStyle(color: KonektaColors.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KonektaColors.textPrimary)),
          const SizedBox(height: 12),
          ..._faqs.map((f) => _FaqTile(question: f.$1, answer: f.$2)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Still need help?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: KonektaColors.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  "Send us an email and we'll get back to you as soon as we can.",
                  style: TextStyle(fontSize: 13, color: KonektaColors.textSecondary),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _emailSupport,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('support@konekta.app'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: KonektaColors.primary),
                      foregroundColor: KonektaColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KonektaColors.textPrimary)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer, style: const TextStyle(fontSize: 13, color: KonektaColors.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}