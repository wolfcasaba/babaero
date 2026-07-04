import '../../../core/supabase/supabase_config.dart';
import 'profile_models.dart';

/// Reads discover-able member profiles.
abstract class DiscoverRepository {
  /// Profiles to browse, excluding the signed-in user.
  Future<List<Profile>> browse({int limit = 30});
}

/// Real implementation — reads `babaero.profiles`.
class SupabaseDiscoverRepository implements DiscoverRepository {
  @override
  Future<List<Profile>> browse({int limit = 30}) async {
    final myId = SupabaseConfig.client.auth.currentUser?.id;
    var query = SupabaseConfig.db.from('profiles').select();
    if (myId != null) {
      query = query.neq('id', myId);
    }
    final rows = await query.order('last_active', ascending: false).limit(limit);
    return (rows as List)
        .map((e) => Profile.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

/// Preview / mock-mode implementation — in-memory seed.
class PreviewDiscoverRepository implements DiscoverRepository {
  @override
  Future<List<Profile>> browse({int limit = 30}) async =>
      sampleProfiles.take(limit).toList();
}
