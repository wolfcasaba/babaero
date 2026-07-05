import '../../../core/supabase/supabase_config.dart';
import 'discover_filters.dart';
import 'profile_models.dart';

/// Reads discover-able member profiles.
abstract class DiscoverRepository {
  /// Profiles to browse, excluding the signed-in user. When [filters] is given,
  /// the hard constraints (gender/age/verified/online/city) are applied
  /// server-side so the fetch budget isn't spent on rows the user filtered out.
  Future<List<Profile>> browse({int limit = 50, DiscoverFilters? filters});
}

/// Real implementation — reads `babaero.profiles`.
class SupabaseDiscoverRepository implements DiscoverRepository {
  @override
  Future<List<Profile>> browse({int limit = 50, DiscoverFilters? filters}) async {
    final myId = SupabaseConfig.client.auth.currentUser?.id;
    var query = SupabaseConfig.db.from('profiles').select();
    if (myId != null) {
      query = query.neq('id', myId);
    }
    if (filters != null) {
      if (filters.gender != null) query = query.eq('gender', filters.gender!);
      if (filters.verifiedOnly) query = query.eq('verified', true);
      if (filters.onlineOnly) query = query.eq('is_online', true);
      if (filters.city != null && filters.city!.isNotEmpty) {
        query = query.ilike('city', '%${filters.city}%');
      }
      // Only constrain age when the user actually narrowed the range — pushing
      // gte/lte to SQL would otherwise drop profiles with a null age.
      if (filters.minAge != kMinFilterAge || filters.maxAge != kMaxFilterAge) {
        query = query.gte('age', filters.minAge).lte('age', filters.maxAge);
      }
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
  Future<List<Profile>> browse({int limit = 50, DiscoverFilters? filters}) async =>
      sampleProfiles.take(limit).toList();
}
