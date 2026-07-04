import '../../../core/supabase/supabase_config.dart';

/// Records photo/video/id verification requests in babaero.verifications.
class VerificationRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  /// Latest request status for the signed-in user, or null if none.
  Future<String?> latestStatus() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await SupabaseConfig.db
        .from('verifications')
        .select('status')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['status'] as String?;
  }

  Future<void> submit(String type, {String? evidence}) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('verifications').insert({
      'user_id': uid,
      'type': type,
      'status': 'pending',
      'evidence': ?evidence,
    });
  }
}
