import '../../../core/supabase/supabase_config.dart';

/// Stores/removes the device's FCM push token in babaero.device_tokens.
///
/// This is the client contract the (future) native push layer calls into:
/// once `firebase_messaging` is wired up (google-services.json + APNs), call
/// [registerToken] with the FCM token after sign-in, and [removeToken] on
/// sign-out. A server / Supabase edge function reads device_tokens to deliver
/// pushes on new matches and messages.
class PushRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  Future<void> registerToken(String token, {String? platform}) async {
    final uid = _uid;
    if (uid == null || token.isEmpty) return;
    await SupabaseConfig.db.from('device_tokens').upsert({
      'user_id': uid,
      'token': token,
      'platform': ?platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
  }

  Future<void> removeToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db
        .from('device_tokens')
        .delete()
        .eq('user_id', uid)
        .eq('token', token);
  }
}
