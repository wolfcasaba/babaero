import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/data/auth_provider.dart';
import 'stories_models.dart';
import 'stories_repository.dart';

/// Real Supabase repo when configured AND signed in, else the preview seed.
final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  ref.watch(currentUserIdProvider);
  if (SupabaseConfig.isConfigured && SupabaseConfig.isSignedIn) {
    return SupabaseStoryRepository();
  }
  return PreviewStoryRepository();
});

/// Active (last-24h) stories, grouped by author.
final storiesProvider = FutureProvider<List<StoryGroup>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(storyRepositoryProvider).activeStories();
});
