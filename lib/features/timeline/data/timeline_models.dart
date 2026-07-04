import '../../discover/data/profile_models.dart';

/// One timeline post: text and/or an image, authored by a member.
/// Parsed at the boundary; the [author] profile and [likedByMe] flag are joined
/// in the repository (PostgREST rows carry only ids + counters).
class Post {
  final String id;
  final String authorId;
  final Profile author;
  final String content;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.authorId,
    required this.author,
    required this.content,
    required this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  Post copyWith({bool? likedByMe, int? likeCount, int? commentCount}) => Post(
        id: id,
        authorId: authorId,
        author: author,
        content: content,
        imageUrl: imageUrl,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        createdAt: createdAt,
      );

  /// Build from a `babaero.posts` row + a resolved [author] + my-like flag.
  factory Post.fromMap(
    Map<String, dynamic> m, {
    required Profile author,
    required bool likedByMe,
  }) =>
      Post(
        id: m['id'].toString(),
        authorId: m['author_id'].toString(),
        author: author,
        content: (m['content'] ?? '').toString(),
        imageUrl: (m['image_url'] as String?)?.isEmpty ?? true
            ? null
            : m['image_url'] as String,
        likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (m['comment_count'] as num?)?.toInt() ?? 0,
        likedByMe: likedByMe,
        createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
      );
}

/// A flat comment under a post.
class PostComment {
  final String id;
  final String postId;
  final Profile author;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromMap(
    Map<String, dynamic> m, {
    required Profile author,
  }) =>
      PostComment(
        id: m['id'].toString(),
        postId: m['post_id'].toString(),
        author: author,
        content: (m['content'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
      );
}
