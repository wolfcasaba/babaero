import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';
import 'timeline_models.dart';

/// Reads/writes the social feed: posts, likes, comments.
abstract class TimelineRepository {
  /// Newest posts first, with author profile + my-like flag resolved.
  Future<List<Post>> feed({int limit = 50});

  /// Upload a feed image; returns its public URL (or null when not signed in).
  Future<String?> uploadPostImage(Uint8List bytes, {String ext = 'jpg'});

  /// Create a post. At least one of [content] / [imageUrl] must be non-empty.
  Future<void> createPost({required String content, String? imageUrl});

  /// Like ([liked] = true) or unlike a post.
  Future<void> setLiked(String postId, bool liked);

  /// Comments under a post, oldest first, with author profiles resolved.
  Future<List<PostComment>> comments(String postId);

  /// Add a comment; returns nothing (caller re-fetches).
  Future<void> addComment(String postId, String content);
}

/// Real implementation — backed by babaero.posts / .post_likes / .post_comments.
class SupabaseTimelineRepository implements TimelineRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  @override
  Future<List<Post>> feed({int limit = 50}) async {
    final rows = await SupabaseConfig.db
        .from('posts')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final postRows = (rows as List).cast<Map<String, dynamic>>();
    if (postRows.isEmpty) return [];

    final authorIds = {for (final p in postRows) p['author_id'] as String};
    final profiles = await _profilesById(authorIds);

    // Which of these posts have I liked? One query, not one per card.
    final me = _uid;
    final likedIds = <String>{};
    if (me != null) {
      final postIds = [for (final p in postRows) p['id'] as String];
      final likeRows = await SupabaseConfig.db
          .from('post_likes')
          .select('post_id')
          .eq('user_id', me)
          .inFilter('post_id', postIds);
      for (final l in likeRows as List) {
        likedIds.add((l as Map<String, dynamic>)['post_id'].toString());
      }
    }

    return [
      for (final p in postRows)
        Post.fromMap(
          p,
          author: profiles[p['author_id']] ?? _unknownProfile(),
          likedByMe: likedIds.contains(p['id'].toString()),
        ),
    ];
  }

  @override
  Future<String?> uploadPostImage(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _uid;
    if (uid == null) return null;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = SupabaseConfig.client.storage.from('posts');
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
  Future<void> createPost({required String content, String? imageUrl}) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('posts').insert({
      'author_id': uid,
      'content': content,
      'image_url': ?imageUrl,
    });
  }

  @override
  Future<void> setLiked(String postId, bool liked) async {
    final uid = _uid;
    if (uid == null) return;
    if (liked) {
      await SupabaseConfig.db.from('post_likes').upsert(
        {'post_id': postId, 'user_id': uid},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      );
    } else {
      await SupabaseConfig.db
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  @override
  Future<List<PostComment>> comments(String postId) async {
    final rows = await SupabaseConfig.db
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    final commentRows = (rows as List).cast<Map<String, dynamic>>();
    if (commentRows.isEmpty) return [];

    final authorIds = {for (final c in commentRows) c['user_id'] as String};
    final profiles = await _profilesById(authorIds);
    return [
      for (final c in commentRows)
        PostComment.fromMap(c, author: profiles[c['user_id']] ?? _unknownProfile()),
    ];
  }

  @override
  Future<void> addComment(String postId, String content) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('post_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'content': content,
    });
  }

  /// Batch-fetch profiles for a set of ids (mirrors the chat repository).
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

/// Preview / mock-mode implementation — an in-memory seed that supports local
/// mutation so the feed feels alive in previews / golden screenshots.
class PreviewTimelineRepository implements TimelineRepository {
  @override
  Future<List<Post>> feed({int limit = 50}) async =>
      _seed.take(limit).toList(growable: false);

  @override
  Future<String?> uploadPostImage(Uint8List bytes, {String ext = 'jpg'}) async =>
      null;

  @override
  Future<void> createPost({required String content, String? imageUrl}) async {
    final me = sampleProfiles.first;
    _seed.insert(
      0,
      Post(
        id: 'local-${_seed.length}',
        authorId: me.id,
        author: me,
        content: content,
        imageUrl: imageUrl,
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> setLiked(String postId, bool liked) async {
    final i = _seed.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final p = _seed[i];
    _seed[i] = p.copyWith(
      likedByMe: liked,
      likeCount: (p.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30),
    );
  }

  @override
  Future<List<PostComment>> comments(String postId) async =>
      _comments[postId] ?? const [];

  @override
  Future<void> addComment(String postId, String content) async {
    (_comments[postId] ??= []).add(
      PostComment(
        id: 'c-${DateTime.now().microsecondsSinceEpoch}',
        postId: postId,
        author: sampleProfiles.first,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
  }
}

/// Fallback profile for a post whose author row could not be resolved.
Profile _unknownProfile() => const Profile(
      id: '',
      name: 'Member',
      age: 0,
      city: '',
      country: '',
      bio: '',
      interests: [],
      verified: false,
      online: false,
      distanceKm: 0,
      languages: '',
      colorA: Color(0xFFE01E5A),
      colorB: Color(0xFFFF7A59),
    );

/// In-memory preview feed. Deterministic (no DateTime.now at top level so
/// golden tests stay stable) — timestamps are fixed offsets from a base.
final List<Post> _seed = [
  Post(
    id: 'seed-1',
    authorId: sampleProfiles[0].id,
    author: sampleProfiles[0],
    content:
        'Sunset at the beach today 🌅 Feeling grateful. Sino gusto mag-beach '
        'trip next week? 🏖️',
    imageUrl: null,
    likeCount: 24,
    commentCount: 3,
    likedByMe: false,
    createdAt: DateTime(2026, 7, 4, 18, 20),
  ),
  Post(
    id: 'seed-2',
    authorId: sampleProfiles[2].id,
    author: sampleProfiles[2],
    content: 'New batch of homemade ube pastries done! Baking keeps me happy. 💜',
    imageUrl: null,
    likeCount: 41,
    commentCount: 7,
    likedByMe: true,
    createdAt: DateTime(2026, 7, 4, 14, 5),
  ),
  Post(
    id: 'seed-3',
    authorId: sampleProfiles[1].id,
    author: sampleProfiles[1],
    content: 'Night shift done. Coffee first, then gym. What keeps you motivated?',
    imageUrl: null,
    likeCount: 12,
    commentCount: 1,
    likedByMe: false,
    createdAt: DateTime(2026, 7, 4, 7, 40),
  ),
];

final Map<String, List<PostComment>> _comments = {
  'seed-1': [
    PostComment(
      id: 'sc-1',
      postId: 'seed-1',
      author: sampleProfiles[3],
      content: 'Ang ganda! Count me in 🙌',
      createdAt: DateTime(2026, 7, 4, 18, 40),
    ),
  ],
};
