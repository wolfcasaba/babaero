import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/data/auth_provider.dart';
import '../../discover/data/profile_models.dart';
import 'matches_repository.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) {
  if (SupabaseConfig.isConfigured && SupabaseConfig.isSignedIn) {
    return SupabaseMatchesRepository();
  }
  return PreviewMatchesRepository();
});

final matchesProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(matchesRepositoryProvider).matches();
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
