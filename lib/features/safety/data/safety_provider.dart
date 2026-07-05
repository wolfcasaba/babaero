import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_provider.dart';
import '../../discover/data/profile_models.dart';
import 'safety_repository.dart';

final safetyRepositoryProvider =
    Provider<SafetyRepository>((_) => SafetyRepository());

/// The set of user ids the current member has blocked. Watched by Discover so
/// blocked members disappear from the browse deck.
final blockedIdsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(safetyRepositoryProvider).blockedIds();
});

/// The blocked members' full profiles, for the Safety & privacy screen.
final blockedProfilesProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(safetyRepositoryProvider).blockedProfiles();
});
