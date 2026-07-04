import 'dart:ui' show Color;

import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';
import 'chat_models.dart';

/// Conversations + messages, backed by babaero.conversations / .messages.
class ChatRepository {
  String? get myId => SupabaseConfig.client.auth.currentUser?.id;

  /// All the current user's conversations, newest activity first.
  Future<List<ConversationView>> conversations() async {
    final me = myId;
    if (me == null) return [];
    final convs = await SupabaseConfig.db
        .from('conversations')
        .select('id, user_low, user_high, last_message_at')
        .or('user_low.eq.$me,user_high.eq.$me')
        .order('last_message_at', ascending: false);

    final convList = (convs as List).cast<Map<String, dynamic>>();
    if (convList.isEmpty) return [];

    final otherIds = <String>[
      for (final c in convList)
        (c['user_low'] == me ? c['user_high'] : c['user_low']) as String,
    ];
    final convIds = [for (final c in convList) c['id'] as String];

    final profileRows = await SupabaseConfig.db
        .from('profiles')
        .select()
        .inFilter('id', otherIds);
    final profiles = {
      for (final p in profileRows as List)
        (p as Map<String, dynamic>)['id'] as String: Profile.fromMap(p),
    };

    // Last message per conversation (fetch recent, keep first seen per conv).
    final msgRows = await SupabaseConfig.db
        .from('messages')
        .select()
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: false);
    final lastByConv = <String, Message>{};
    for (final m in msgRows as List) {
      final msg = Message.fromMap(m as Map<String, dynamic>);
      lastByConv.putIfAbsent(msg.conversationId, () => msg);
    }

    return [
      for (final c in convList)
        ConversationView(
          id: c['id'] as String,
          other: profiles[
                  (c['user_low'] == me ? c['user_high'] : c['user_low'])] ??
              _unknownProfile(),
          lastMessage: lastByConv[c['id']],
          lastMessageAt:
              DateTime.parse(c['last_message_at'].toString()).toLocal(),
        ),
    ];
  }

  /// Demo-only: trigger a canned reply from the other participant.
  Future<void> demoAutoreply(String conversationId) async {
    await SupabaseConfig.db
        .rpc('demo_autoreply', params: {'conv': conversationId});
  }

  Future<String?> getOrCreateConversationWith(String otherUserId) async {
    final res = await SupabaseConfig.db
        .rpc('get_or_create_conversation', params: {'other': otherUserId});
    return res?.toString();
  }

  Future<List<Message>> messages(String conversationId) async {
    final rows = await SupabaseConfig.db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return [
      for (final m in rows as List) Message.fromMap(m as Map<String, dynamic>)
    ];
  }

  Future<void> send({
    required String conversationId,
    required String body,
    String? translatedBody,
    String? sourceLang,
    String? targetLang,
  }) async {
    final me = myId;
    if (me == null) return;
    await SupabaseConfig.db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': me,
      'body': body,
      'translated_body': ?translatedBody,
      'source_lang': ?sourceLang,
      'target_lang': ?targetLang,
    });
  }

  /// Realtime stream of the conversation's messages (ordered).
  Stream<List<Message>> messageStream(String conversationId) {
    return SupabaseConfig.db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(Message.fromMap).toList());
  }

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
}
