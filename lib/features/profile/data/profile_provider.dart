import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_provider.dart';
import '../../discover/data/profile_models.dart';
import 'profile_repository.dart';

final profileRepositoryProvider =
    Provider<ProfileRepository>((_) => ProfileRepository());

/// The signed-in member's own profile (null when logged out / not yet set up).
final myProfileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(currentUserIdProvider); // refetch when the user changes
  return ref.watch(profileRepositoryProvider).getMine();
});
