import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Realtime pulse for new matches + incoming likes, so the Matches tab and the
/// "likes you" count update live instead of only on pull-to-refresh.
final matchPulseProvider = StreamProvider<int>((ref) {
  if (!SupabaseConfig.isConfigured || !SupabaseConfig.isSignedIn) {
    return const Stream<int>.empty();
  }
  final controller = StreamController<int>();
  var tick = 0;
  void bump(PostgresChangePayload _) => controller.add(++tick);

  final channel = SupabaseConfig.client
      .channel('match-pulse')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'babaero',
        table: 'matches',
        callback: bump,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'babaero',
        table: 'likes',
        callback: bump,
      )
      .subscribe();

  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

final matchesProvider = FutureProvider<List<Profile>>((ref) async {
  ref.watch(currentUserIdProvider);
  ref.watch(matchPulseProvider);
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
  ref.watch(matchPulseProvider);
  return ref.watch(matchesRepositoryProvider).likesYouCount();
});

/// The profiles who liked the current user.
final whoLikedMeProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(currentUserIdProvider);
  ref.watch(matchPulseProvider);
  return ref.watch(matchesRepositoryProvider).whoLikedMe();
});

/// Ids the current user has already liked — used to filter the Discover deck.
final likedIdsProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(matchesRepositoryProvider).likedIds();
});
