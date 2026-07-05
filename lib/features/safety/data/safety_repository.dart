import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';

/// Block + report writes, backed by babaero.blocks / babaero.reports.
class SafetyRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  /// Ids the current user has blocked (hidden from Discover).
  Future<Set<String>> blockedIds() async {
    final me = _uid;
    if (me == null) return {};
    final rows = await SupabaseConfig.db
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', me);
    return {for (final r in rows as List) (r as Map)['blocked_id'] as String};
  }

  /// The blocked members' profiles, for the "Safety & privacy" list.
  Future<List<Profile>> blockedProfiles() async {
    final ids = await blockedIds();
    if (ids.isEmpty) return [];
    final rows = await SupabaseConfig.db
        .from('profiles')
        .select()
        .inFilter('id', ids.toList());
    return [
      for (final r in rows as List) Profile.fromMap(r as Map<String, dynamic>)
    ];
  }

  Future<void> block(String userId) async {
    final me = _uid;
    if (me == null || me == userId) return;
    await SupabaseConfig.db.from('blocks').upsert({
      'blocker_id': me,
      'blocked_id': userId,
    });
  }

  Future<void> unblock(String userId) async {
    final me = _uid;
    if (me == null) return;
    await SupabaseConfig.db
        .from('blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', userId);
  }

  Future<void> report(String userId,
      {required String reason, String? details}) async {
    final me = _uid;
    if (me == null) return;
    await SupabaseConfig.db.from('reports').insert({
      'reporter_id': me,
      'reported_id': userId,
      'reason': reason,
      'details': ?details,
    });
  }
}
