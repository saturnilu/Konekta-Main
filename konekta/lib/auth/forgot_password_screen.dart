import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/app_scope.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }
    final scope = AppScope.of(context);
    setState(() => _loading = true);
    try {
      final res = await scope.api.post('/auth/forgot-password', {'email': email}, auth: false);
      if (!mounted) return;
      final map = Map<String, dynamic>.from(res as Map);
      setState(() { _loading = false; _sent = true; });
      final devToken = map['dev_token']?.toString();
      if (devToken != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(prefilledToken: devToken)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: KonektaColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Forgot password?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: KonektaColors.textPrimary)),
              const SizedBox(height: 10),
              const Text(
                "Enter the email on your account and we'll send you a link to reset your password.",
                style: TextStyle(fontSize: 14, color: KonektaColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              if (_sent) ...[
                const _SentNotice(),
              ] else ...[
                const Text('Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'name@company.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded, color: KonektaColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: _loading ? 'Sending...' : 'Send reset link',
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SentNotice extends StatelessWidget {
  const _SentNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KonektaColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KonektaColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, color: KonektaColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "If that email is registered, we've sent a link to reset your password. Check your inbox (and spam folder).",
              style: TextStyle(fontSize: 13, color: KonektaColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}