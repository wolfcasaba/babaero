import '../../discover/data/profile_models.dart';

/// One 24h story (a photo + optional caption).
class Story {
  final String id;
  final String authorId;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;

  const Story({
    required this.id,
    required this.authorId,
    required this.imageUrl,
    required this.createdAt,
    this.caption,
  });

  factory Story.fromMap(Map<String, dynamic> m) => Story(
        id: m['id'].toString(),
        authorId: m['author_id'].toString(),
        imageUrl: (m['image_url'] ?? '').toString(),
        caption: m['caption'] as String?,
        createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
      );
}

/// All of one author's active stories, plus whether any are unseen (ring color).
class StoryGroup {
  final Profile author;
  final List<Story> stories;
  final bool isMine;
  final bool hasUnseen;

  const StoryGroup({
    required this.author,
    required this.stories,
    required this.isMine,
    required this.hasUnseen,
  });
}
