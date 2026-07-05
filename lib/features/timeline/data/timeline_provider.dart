import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/data/auth_provider.dart';
import '../../safety/data/safety_provider.dart';
import 'timeline_models.dart';
import 'timeline_repository.dart';

/// Real Supabase repo when configured AND signed in, else the preview seed —
/// the repository-provider pattern used across the app.
final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  ref.watch(currentUserIdProvider); // rebuild the repo choice on auth changes
  if (SupabaseConfig.isConfigured && SupabaseConfig.isSignedIn) {
    return SupabaseTimelineRepository();
  }
  return PreviewTimelineRepository();
});

/// Realtime pulse for new posts — drives the "New posts" pill without auto
/// refetching (which would reset pagination). Emits a tick per inserted post.
final feedPulseProvider = StreamProvider<int>((ref) {
  if (!SupabaseConfig.isConfigured || !SupabaseConfig.isSignedIn) {
    return const Stream<int>.empty();
  }
  final controller = StreamController<int>();
  var tick = 0;
  final channel = SupabaseConfig.client
      .channel('feed-pulse')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'babaero',
        table: 'posts',
        callback: (_) => controller.add(++tick),
      )
      .subscribe();
  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

const int kFeedPageSize = 20;

/// The timeline feed (newest first) with cursor pagination for infinite scroll.
/// `ref.invalidate(feedProvider)` reloads the first page; `loadMore()` appends
/// the next page keyed on the oldest loaded post's timestamp.
class FeedNotifier extends AsyncNotifier<List<Post>> {
  bool _reachedEnd = false;
  bool _loadingMore = false;

  bool get reachedEnd => _reachedEnd;

  @override
  Future<List<Post>> build() async {
    ref.watch(currentUserIdProvider);
    _reachedEnd = false;
    final blocked = await ref.watch(blockedIdsProvider.future);
    final page =
        await ref.watch(timelineRepositoryProvider).feed(limit: kFeedPageSize);
    // reachedEnd tracks the RAW fetch size (before hiding blocked authors) so
    // paging stays correct even when a full page is all blocked.
    if (page.length < kFeedPageSize) _reachedEnd = true;
    return [
      for (final p in page)
        if (!blocked.contains(p.authorId)) p,
    ];
  }

  /// Append the next page. No-ops at the end or while a page is in flight.
  Future<void> loadMore() async {
    if (_reachedEnd || _loadingMore) return;
    final current = state.asData?.value;
    if (current == null || current.isEmpty) return;
    _loadingMore = true;
    try {
      final blocked = ref.read(blockedIdsProvider).asData?.value ?? const {};
      final more = await ref.read(timelineRepositoryProvider).feed(
            limit: kFeedPageSize,
            before: current.last.createdAt,
          );
      if (more.length < kFeedPageSize) _reachedEnd = true;
      // Dedup by id (shared boundary timestamps) + hide blocked authors.
      final seen = {for (final p in current) p.id};
      state = AsyncData([
        ...current,
        for (final p in more)
          if (!seen.contains(p.id) && !blocked.contains(p.authorId)) p,
      ]);
    } catch (_) {
      // keep the current page; the next scroll can retry
    } finally {
      _loadingMore = false;
    }
  }
}

final feedProvider =
    AsyncNotifierProvider<FeedNotifier, List<Post>>(FeedNotifier.new);

/// Comments for one post (oldest first).
final postCommentsProvider =
    FutureProvider.family<List<PostComment>, String>((ref, postId) {
  return ref.watch(timelineRepositoryProvider).comments(postId);
});
