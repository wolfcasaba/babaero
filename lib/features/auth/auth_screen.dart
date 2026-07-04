import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../profile/data/profile_provider.dart';
import '../profile/onboarding_setup_screen.dart';
import 'data/auth_provider.dart';

/// Email + password sign-in / sign-up. `startInSignUp` picks the initial mode.
class AuthScreen extends ConsumerStatefulWidget {
  final bool startInSignUp;
  const AuthScreen({super.key, required this.startInSignUp});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _signUp = widget.startInSignUp;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || !email.contains('@') || pw.length < 6) {
      setState(() => _error = 'Enter a valid email and a 6+ char password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_signUp) {
        final res = await repo.signUp(email: email, password: pw);
        if (!mounted) return;
        if (res.session == null) {
          // Email confirmation is required (no immediate session) — tell the
          // user to confirm, then switch to sign-in.
          await _showConfirmEmail(email);
          if (!mounted) return;
          setState(() => _signUp = false);
          return;
        }
        // Immediate session → collect profile, then drop back to the gate.
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingSetupScreen()),
        );
        if (!mounted) return;
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        await repo.signIn(email: email, password: pw);
        if (!mounted) return;
        // First sign-in without a profile yet → collect it.
        final hasProfile =
            await ref.read(profileRepositoryProvider).getMine() != null;
        if (!mounted) return;
        if (!hasProfile) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OnboardingSetupScreen()),
          );
          if (!mounted) return;
        }
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConfirmEmail(String email) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your email'),
        content: Text(
          'We sent a confirmation link to $email. Tap it, then sign in here.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException') ||
        s.contains('Connection') ||
        s.contains('timed out') ||
        s.contains('XMLHttpRequest')) {
      return 'Can\'t reach the server. Check your internet and try again.';
    }
    if (s.contains('already registered') || s.contains('User already')) {
      return 'That email is already in use. Try signing in.';
    }
    if (s.contains('Invalid login')) return 'Wrong email or password.';
    if (s.contains('Password should') || s.contains('weak')) {
      return 'Password too weak — use at least 6 characters.';
    }
    if (s.contains('sending confirmation') || s.contains('rate limit')) {
      return 'Email confirmation is failing. Ask the admin to turn off '
          '“Confirm email”, then try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandWordmark(fontSize: 30),
              const SizedBox(height: 8),
              Text(
                _signUp ? 'Create your account' : 'Welcome back',
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(LucideIcons.mail),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(LucideIcons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? LucideIcons.eye : LucideIcons.eyeOff),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 24),
              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : GradientButton(
                      label: _signUp ? 'Create account' : 'Sign in',
                      onPressed: _submit,
                    ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _signUp = !_signUp;
                    _error = null;
                  }),
                  child: Text.rich(
                    TextSpan(
                      text: _signUp
                          ? 'Already have an account? '
                          : 'New here? ',
                      style: TextStyle(color: cs.outline),
                      children: [
                        TextSpan(
                          text: _signUp ? 'Sign in' : 'Create account',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
