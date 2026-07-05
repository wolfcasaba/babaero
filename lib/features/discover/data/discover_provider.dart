import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../matches/data/matches_provider.dart';
import '../../safety/data/safety_provider.dart';
import 'discover_filters.dart';
import 'discover_repository.dart';
import 'profile_models.dart';

/// Real Supabase repo when configured AND signed in, else the preview seed —
/// the repository-provider pattern used across the app.
final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  if (SupabaseConfig.isConfigured && SupabaseConfig.isSignedIn) {
    return SupabaseDiscoverRepository();
  }
  return PreviewDiscoverRepository();
});

/// The list of profiles to browse in Discover — minus anyone the user blocked,
/// minus anyone already liked (so they never reappear after a swipe), minus
/// anyone excluded by the active filters.
final discoverProfilesProvider = FutureProvider<List<Profile>>((ref) async {
  final blocked = await ref.watch(blockedIdsProvider.future);
  final liked = await ref.watch(likedIdsProvider.future);
  final filters = ref.watch(discoverFiltersProvider);
  final profiles = await ref.watch(discoverRepositoryProvider).browse();
  return [
    for (final p in profiles)
      if (!blocked.contains(p.id) && !liked.contains(p.id) && filters.matches(p))
        p,
  ];
});
