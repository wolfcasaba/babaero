import '../../discover/data/profile_models.dart';

/// One chat message.
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String? translatedBody;
  final String? imageUrl;
  final DateTime createdAt;

  /// When the recipient read this message (null = unread). Drives the ✓/✓✓
  /// read receipt on the sender's own bubbles.
  final DateTime? readAt;

  /// Voice note: public URL to the audio clip + its duration in milliseconds.
  final String? voiceUrl;
  final int? voiceDurMs;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.translatedBody,
    this.imageUrl,
    this.readAt,
    this.voiceUrl,
    this.voiceDurMs,
  });

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'].toString(),
        conversationId: m['conversation_id'].toString(),
        senderId: m['sender_id'].toString(),
        body: (m['body'] ?? '').toString(),
        translatedBody: m['translated_body'] as String?,
        imageUrl: m['image_url'] as String?,
        createdAt: DateTime.parse(m['created_at'].toString()).toLocal(),
        readAt: m['read_at'] == null
            ? null
            : DateTime.parse(m['read_at'].toString()).toLocal(),
        voiceUrl: m['voice_url'] as String?,
        voiceDurMs: (m['voice_dur_ms'] as num?)?.toInt(),
      );

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasVoice => voiceUrl != null && voiceUrl!.isNotEmpty;
  bool get isRead => readAt != null;
  bool mine(String? myId) => senderId == myId;
}

/// A conversation row joined with the other member's profile + last message.
class ConversationView {
  final String id;
  final Profile other;
  final Message? lastMessage;
  final DateTime lastMessageAt;

  /// Count of incoming messages the current user hasn't read yet.
  final int unreadCount;

  const ConversationView({
    required this.id,
    required this.other,
    required this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  bool get hasUnread => unreadCount > 0;
}
