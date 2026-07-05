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

  /// Send a password-reset email. The user follows the link to set a new one.
  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email.trim());

  /// Permanently delete the current account via the `delete-account` edge
  /// function (a client can't delete its own auth user). The session token is
  /// attached automatically; babaero.* rows cascade off auth.users. Signs out
  /// locally afterwards.
  Future<void> deleteAccount() async {
    await SupabaseConfig.client.functions.invoke('delete-account');
    await signOut();
  }
}
