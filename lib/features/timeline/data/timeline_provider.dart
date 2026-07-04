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

/// The timeline feed (newest first).
final feedProvider = FutureProvider<List<Post>>((ref) {
  return ref.watch(timelineRepositoryProvider).feed();
});

/// Comments for one post (oldest first).
final postCommentsProvider =
    FutureProvider.family<List<PostComment>, String>((ref, postId) {
  return ref.watch(timelineRepositoryProvider).comments(postId);
});
