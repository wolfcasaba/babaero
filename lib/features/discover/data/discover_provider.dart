import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
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

/// The list of profiles to browse in Discover.
final discoverProfilesProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(discoverRepositoryProvider).browse();
});
