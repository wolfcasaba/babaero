import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';
import 'stories_models.dart';

/// Reads/writes 24h stories.
abstract class StoryRepository {
  /// Active stories (last 24h), grouped by author — the current user first,
  /// then others, unseen groups ahead of fully-seen ones.
  Future<List<StoryGroup>> activeStories();

  Future<String?> uploadStoryImage(Uint8List bytes, {String ext = 'jpg'});
  Future<void> addStory({required String imageUrl, String? caption});
  Future<void> markViewed(String storyId);

  /// Profiles who viewed a story (author-only, for the "seen by" list).
  Future<List<Profile>> viewers(String storyId);

  /// Delete one of the current user's own stories.
  Future<void> deleteStory(String storyId);
}

class SupabaseStoryRepository implements StoryRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  @override
  Future<List<StoryGroup>> activeStories() async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final rows = await SupabaseConfig.db
        .from('stories')
        .select()
        .gt('created_at', since)
        .order('created_at', ascending: true);
    final storyRows = (rows as List).cast<Map<String, dynamic>>();
    if (storyRows.isEmpty) return [];

    final authorIds = {for (final s in storyRows) s['author_id'] as String};
    final profiles = await _profilesById(authorIds);

    final me = _uid;
    final seen = <String>{};
    if (me != null) {
      final viewRows = await SupabaseConfig.db
          .from('story_views')
          .select('story_id')
          .eq('viewer_id', me);
      for (final v in viewRows as List) {
        seen.add((v as Map<String, dynamic>)['story_id'].toString());
      }
    }

    final byAuthor = <String, List<Story>>{};
    for (final s in storyRows) {
      byAuthor
          .putIfAbsent(s['author_id'] as String, () => <Story>[])
          .add(Story.fromMap(s));
    }

    final groups = <StoryGroup>[];
    for (final entry in byAuthor.entries) {
      final author = profiles[entry.key];
      if (author == null) continue;
      final hasUnseen = entry.value.any((s) => !seen.contains(s.id));
      groups.add(StoryGroup(
        author: author,
        stories: entry.value,
        isMine: entry.key == me,
        hasUnseen: hasUnseen,
      ));
    }

    // Mine first, then unseen groups, then seen.
    groups.sort((a, b) {
      if (a.isMine != b.isMine) return a.isMine ? -1 : 1;
      if (a.hasUnseen != b.hasUnseen) return a.hasUnseen ? -1 : 1;
      return 0;
    });
    return groups;
  }

  @override
  Future<String?> uploadStoryImage(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _uid;
    if (uid == null) return null;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = SupabaseConfig.client.storage.from('stories');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );
    return storage.getPublicUrl(path);
  }

  @override
  Future<void> addStory({required String imageUrl, String? caption}) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('stories').insert({
      'author_id': uid,
      'image_url': imageUrl,
      'caption': ?caption,
    });
  }

  @override
  Future<void> markViewed(String storyId) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('story_views').upsert(
      {'story_id': storyId, 'viewer_id': uid},
      onConflict: 'story_id,viewer_id',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<List<Profile>> viewers(String storyId) async {
    final rows = await SupabaseConfig.db
        .from('story_views')
        .select('viewer_id')
        .eq('story_id', storyId);
    final ids = [
      for (final r in rows as List) (r as Map)['viewer_id'] as String,
    ];
    if (ids.isEmpty) return [];
    final profiles = await _profilesById(ids.toSet());
    return [for (final id in ids) if (profiles[id] != null) profiles[id]!];
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db
        .from('stories')
        .delete()
        .eq('id', storyId)
        .eq('author_id', uid);
  }

  Future<Map<String, Profile>> _profilesById(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await SupabaseConfig.db
        .from('profiles')
        .select()
        .inFilter('id', ids.toList());
    return {
      for (final p in rows as List)
        (p as Map<String, dynamic>)['id'] as String: Profile.fromMap(p),
    };
  }
}

/// Preview / mock-mode: a couple of sample story groups so the bar renders in
/// logged-out previews and golden screenshots.
class PreviewStoryRepository implements StoryRepository {
  @override
  Future<List<StoryGroup>> activeStories() async {
    DateTime t(int h) => DateTime(2026, 7, 4, h);
    return [
      StoryGroup(
        author: sampleProfiles[0],
        isMine: false,
        hasUnseen: true,
        stories: [
          Story(
              id: 's1',
              authorId: sampleProfiles[0].id,
              imageUrl: '',
              caption: 'Beach day 🌊',
              createdAt: t(9)),
        ],
      ),
      StoryGroup(
        author: sampleProfiles[2],
        isMine: false,
        hasUnseen: true,
        stories: [
          Story(
              id: 's2',
              authorId: sampleProfiles[2].id,
              imageUrl: '',
              createdAt: t(11)),
        ],
      ),
      StoryGroup(
        author: sampleProfiles[1],
        isMine: false,
        hasUnseen: false,
        stories: [
          Story(
              id: 's3',
              authorId: sampleProfiles[1].id,
              imageUrl: '',
              createdAt: t(8)),
        ],
      ),
    ];
  }

  @override
  Future<String?> uploadStoryImage(Uint8List bytes, {String ext = 'jpg'}) async =>
      null;
  @override
  Future<void> addStory({required String imageUrl, String? caption}) async {}
  @override
  Future<void> markViewed(String storyId) async {}
  @override
  Future<List<Profile>> viewers(String storyId) async => const [];
  @override
  Future<void> deleteStory(String storyId) async {}
}
