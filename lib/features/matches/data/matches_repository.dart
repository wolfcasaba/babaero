import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';

/// Likes, matches, and "likes you" reads.
abstract class MatchesRepository {
  /// Record a like; returns true when it became a mutual match.
  Future<bool> like(String targetId, {bool superLike = false});

  /// Profiles the current user has matched with.
  Future<List<Profile>> matches();

  /// How many members have liked the current user.
  Future<int> likesYouCount();
}

class SupabaseMatchesRepository implements MatchesRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  @override
  Future<bool> like(String targetId, {bool superLike = false}) async {
    final res = await SupabaseConfig.db.rpc(
      'like_profile',
      params: {'target': targetId, 'is_super': superLike},
    );
    return res == true;
  }

  @override
  Future<List<Profile>> matches() async {
    final me = _uid;
    if (me == null) return [];
    final rows = await SupabaseConfig.db
        .from('matches')
        .select('user_low, user_high')
        .or('user_low.eq.$me,user_high.eq.$me');
    final otherIds = <String>[
      for (final r in rows as List)
        (r['user_low'] == me ? r['user_high'] : r['user_low']) as String,
    ];
    if (otherIds.isEmpty) return [];
    final profiles = await SupabaseConfig.db
        .from('profiles')
        .select()
        .inFilter('id', otherIds);
    return (profiles as List)
        .map((e) => Profile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> likesYouCount() async {
    final me = _uid;
    if (me == null) return 0;
    final rows =
        await SupabaseConfig.db.from('likes').select('liker_id').eq('liked_id', me);
    return (rows as List).length;
  }
}

/// Mock-mode: sample matches, no writes.
class PreviewMatchesRepository implements MatchesRepository {
  @override
  Future<bool> like(String targetId, {bool superLike = false}) async => false;

  @override
  Future<List<Profile>> matches() async => sampleProfiles.take(4).toList();

  @override
  Future<int> likesYouCount() async => 12;
}
