import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_config.dart';
import '../home/home_shell.dart';
import '../onboarding/welcome_screen.dart';
import 'data/auth_provider.dart';

/// Root routing. Rebuilds on auth changes:
/// - mock mode (no backend) → straight into the app for previews
/// - signed in → HomeShell
/// - signed out → WelcomeScreen
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseConfig.isConfigured) return const HomeShell();
    final userId = ref.watch(currentUserIdProvider);
    return userId != null ? const HomeShell() : const WelcomeScreen();
  }
}
