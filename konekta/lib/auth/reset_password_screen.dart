import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../core/app_scope.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? prefilledToken;
  const ResetPasswordScreen({super.key, this.prefilledToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _token = TextEditingController(text: widget.prefilledToken ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _submit() async {
    final token = _token.text.trim();
    final password = _password.text;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste the reset code from your email')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (password != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    final scope = AppScope.of(context);
    setState(() => _loading = true);
    try {
      await scope.api.post('/auth/reset-password', {'token': token, 'password': password}, auth: false);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated — please sign in')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
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
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Reset password', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: KonektaColors.textPrimary)),
              const SizedBox(height: 10),
              const Text(
                'Paste the code from the email we sent you, then choose a new password.',
                style: TextStyle(fontSize: 14, color: KonektaColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              const Text('Reset code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _token,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Paste the code from your email',
                  prefixIcon: Icon(Icons.key_outlined, color: KonektaColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text('New password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: KonektaColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: KonektaColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Confirm new password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: KonektaColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: _loading ? 'Updating...' : 'Update password',
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}