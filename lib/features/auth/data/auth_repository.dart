import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';

/// Thin wrapper over Supabase auth for Babaero.
class AuthRepository {
  GoTrueClient get _auth => SupabaseConfig.client.auth;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _auth.signUp(email: email.trim(), password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();
}
