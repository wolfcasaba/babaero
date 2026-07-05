import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/data/auth_provider.dart';
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
    final page =
        await ref.watch(timelineRepositoryProvider).feed(limit: kFeedPageSize);
    if (page.length < kFeedPageSize) _reachedEnd = true;
    return page;
  }

  /// Append the next page. No-ops at the end or while a page is in flight.
  Future<void> loadMore() async {
    if (_reachedEnd || _loadingMore) return;
    final current = state.asData?.value;
    if (current == null || current.isEmpty) return;
    _loadingMore = true;
    try {
      final more = await ref.read(timelineRepositoryProvider).feed(
            limit: kFeedPageSize,
            before: current.last.createdAt,
          );
      if (more.length < kFeedPageSize) _reachedEnd = true;
      // Dedup by id in case posts share the boundary timestamp.
      final seen = {for (final p in current) p.id};
      state = AsyncData([
        ...current,
        for (final p in more)
          if (!seen.contains(p.id)) p,
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
