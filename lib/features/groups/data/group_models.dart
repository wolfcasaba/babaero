import '../../discover/data/profile_models.dart';

/// One group chat message. Mirrors [Message] but keyed by group_id, so the
/// same bubble UI and inline-translation logic apply.
class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String body;
  final String? translatedBody;
  final String? imageUrl;
  final DateTime createdAt;

  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.translatedBody,
    this.imageUrl,
  });

  factory GroupMessage.fromMap(Map<String, dynamic> m) => GroupMessage(
        id: m['id'].toString(),
        groupId: m['group_id'].toString(),
        senderId: m['sender_id'].toString(),
        body: (m['body'] ?? '').toString(),
        translatedBody: m['translated_body'] as String?,
        imageUrl: m['image_url'] as String?,
        createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
      );

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool mine(String? myId) => senderId == myId;
}

/// A group row joined with its member profiles + last message, for the list.
class GroupConversationView {
  final String id;
  final String title;
  final String? imageUrl;

  /// Other members (excludes the current user) — used for avatars/subtitle.
  final List<Profile> others;
  final int memberCount;
  final GroupMessage? lastMessage;
  final DateTime lastMessageAt;

  const GroupConversationView({
    required this.id,
    required this.title,
    required this.others,
    required this.memberCount,
    required this.lastMessageAt,
    this.imageUrl,
    this.lastMessage,
  });
}
