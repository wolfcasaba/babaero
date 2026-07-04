import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

/// Streams auth state changes (sign-in / sign-out / token refresh).
/// In mock mode (no backend) emits a single logged-out state.
final authStateProvider = StreamProvider<AuthState?>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const Stream<AuthState?>.empty();
  }
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Convenience: the current signed-in user id (null when logged out / mock).
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider); // rebuild on auth changes
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseConfig.client.auth.currentUser?.id;
});
