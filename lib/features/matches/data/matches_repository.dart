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

  /// The profiles who have liked the current user (the "likes you" list).
  Future<List<Profile>> whoLikedMe();

  /// Ids the current user has already liked — used to keep them out of the
  /// Discover deck so nobody reappears after a swipe.
  Future<Set<String>> likedIds();
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

  @override
  Future<List<Profile>> whoLikedMe() async {
    final me = _uid;
    if (me == null) return [];
    final rows = await SupabaseConfig.db
        .from('likes')
        .select('liker_id')
        .eq('liked_id', me)
        .order('created_at', ascending: false);
    final likerIds = [
      for (final r in rows as List) (r as Map)['liker_id'] as String,
    ];
    if (likerIds.isEmpty) return [];
    final profiles = await SupabaseConfig.db
        .from('profiles')
        .select()
        .inFilter('id', likerIds);
    final byId = {
      for (final p in profiles as List)
        (p as Map<String, dynamic>)['id'] as String:
            Profile.fromMap(p),
    };
    // Preserve the recency order from the likes query (inFilter loses it).
    return [
      for (final id in likerIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<Set<String>> likedIds() async {
    final me = _uid;
    if (me == null) return {};
    final rows = await SupabaseConfig.db
        .from('likes')
        .select('liked_id')
        .eq('liker_id', me);
    return {
      for (final r in rows as List) (r as Map)['liked_id'] as String,
    };
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

  @override
  Future<List<Profile>> whoLikedMe() async => sampleProfiles.take(3).toList();

  @override
  Future<Set<String>> likedIds() async => {};
}
