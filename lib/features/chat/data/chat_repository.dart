import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

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

    // Last message per conversation. Bounded to the most recent messages so
    // this never grows unbounded for heavy users — the conv list is sorted by
    // last_message_at desc, so the newest rows cover the top (visible) convs;
    // older convs fall back to the "say hi" preview.
    final msgRows = await SupabaseConfig.db
        .from('messages')
        .select()
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: false)
        .limit(200);
    final lastByConv = <String, Message>{};
    for (final m in msgRows as List) {
      final msg = Message.fromMap(m as Map<String, dynamic>);
      lastByConv.putIfAbsent(msg.conversationId, () => msg);
    }

    // Unread counts fetched separately as ONLY the unread incoming rows — a
    // small set regardless of total history, so the badge stays accurate even
    // after the last-message fetch above is capped.
    final unreadRows = await SupabaseConfig.db
        .from('messages')
        .select('conversation_id')
        .inFilter('conversation_id', convIds)
        .neq('sender_id', me)
        .isFilter('read_at', null);
    final unreadByConv = <String, int>{};
    for (final r in unreadRows as List) {
      final cid = (r as Map<String, dynamic>)['conversation_id'] as String;
      unreadByConv[cid] = (unreadByConv[cid] ?? 0) + 1;
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
          unreadCount: unreadByConv[c['id']] ?? 0,
        ),
    ];
  }

  /// Demo-only: trigger a canned reply from the other participant.
  Future<void> demoAutoreply(String conversationId) async {
    await SupabaseConfig.db
        .rpc('demo_autoreply', params: {'conv': conversationId});
  }

  /// Mark every incoming (not-mine) message in the conversation as read.
  /// Backed by the security-definer `mark_conversation_read` RPC — the client
  /// can't UPDATE messages directly (no RLS update policy on purpose).
  Future<void> markRead(String conversationId) async {
    await SupabaseConfig.db
        .rpc('mark_conversation_read', params: {'conv': conversationId});
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
    String? imageUrl,
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
      'image_url': ?imageUrl,
    });
  }

  /// Upload a chat image to the sender's folder in the public `chat` bucket.
  Future<String?> uploadImage(Uint8List bytes, {String ext = 'jpg'}) async {
    final me = myId;
    if (me == null) return null;
    final path = '$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = SupabaseConfig.client.storage.from('chat');
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
