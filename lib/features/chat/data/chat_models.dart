import '../../discover/data/profile_models.dart';

/// One chat message.
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String? translatedBody;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.translatedBody,
  });

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'].toString(),
        conversationId: m['conversation_id'].toString(),
        senderId: m['sender_id'].toString(),
        body: (m['body'] ?? '').toString(),
        translatedBody: m['translated_body'] as String?,
        createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
      );

  bool mine(String? myId) => senderId == myId;
}

/// A conversation row joined with the other member's profile + last message.
class ConversationView {
  final String id;
  final Profile other;
  final Message? lastMessage;
  final DateTime lastMessageAt;

  const ConversationView({
    required this.id,
    required this.other,
    required this.lastMessageAt,
    this.lastMessage,
  });
}
