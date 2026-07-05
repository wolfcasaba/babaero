import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/data/auth_provider.dart';
import '../../discover/data/profile_models.dart';
import '../../safety/data/safety_provider.dart';
import 'matches_repository.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  if (SupabaseConfig.isConfigured && SupabaseConfig.isSignedIn) {
    return SupabaseMatchesRepository();
  }
  return PreviewMatchesRepository();
});

final matchesProvider = FutureProvider<List<Profile>>((ref) async {
  ref.watch(currentUserIdProvider);
  final blocked = await ref.watch(blockedIdsProvider.future);
  final all = await ref.watch(matchesRepositoryProvider).matches();
  // A blocked member disappears from your matches list too, not just Discover.
  return [
    for (final p in all)
      if (!blocked.contains(p.id)) p,
  ];
});

final likesYouCountProvider = FutureProvider<int>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(matchesRepositoryProvider).likesYouCount();
});

/// The profiles who liked the current user.
final whoLikedMeProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(matchesRepositoryProvider).whoLikedMe();
});

/// Ids the current user has already liked — used to filter the Discover deck.
final likedIdsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(matchesRepositoryProvider).likedIds();
});
