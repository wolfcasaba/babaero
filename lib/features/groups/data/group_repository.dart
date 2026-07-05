import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';
import 'group_models.dart';

/// Group conversations + messages, backed by the babaero.group_* tables.
/// A strictly separate subsystem from 1:1 [ChatRepository] — the working chat,
/// its demo_autoreply and translation are untouched.
class GroupRepository {
  String? get myId => SupabaseConfig.client.auth.currentUser?.id;

  /// All groups the current user belongs to, newest activity first.
  Future<List<GroupConversationView>> groups() async {
    final me = myId;
    if (me == null) return [];

    // Groups I'm a member of.
    final myRows = await SupabaseConfig.db
        .from('group_members')
        .select('group_id')
        .eq('user_id', me);
    final groupIds = [
      for (final r in myRows as List) (r as Map)['group_id'] as String,
    ];
    if (groupIds.isEmpty) return [];

    final convRows = await SupabaseConfig.db
        .from('group_conversations')
        .select('id, title, image_url, last_message_at')
        .inFilter('id', groupIds)
        .order('last_message_at', ascending: false);
    final convList = (convRows as List).cast<Map<String, dynamic>>();
    if (convList.isEmpty) return [];

    // All members of those groups (roster), then their profiles in one query.
    final memberRows = await SupabaseConfig.db
        .from('group_members')
        .select('group_id, user_id')
        .inFilter('group_id', groupIds);
    final membersByGroup = <String, List<String>>{};
    for (final r in memberRows as List) {
      final map = r as Map<String, dynamic>;
      membersByGroup
          .putIfAbsent(map['group_id'] as String, () => <String>[])
          .add(map['user_id'] as String);
    }

    final allUserIds = {
      for (final ids in membersByGroup.values) ...ids,
    }.toList();
    final profiles = await _profilesByIds(allUserIds);

    // Last message per group (fetch recent desc, keep first seen per group).
    final msgRows = await SupabaseConfig.db
        .from('group_messages')
        .select()
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false);
    final lastByGroup = <String, GroupMessage>{};
    for (final m in msgRows as List) {
      final msg = GroupMessage.fromMap(m as Map<String, dynamic>);
      lastByGroup.putIfAbsent(msg.groupId, () => msg);
    }

    return [
      for (final c in convList)
        () {
          final ids = membersByGroup[c['id']] ?? const <String>[];
          final others = [
            for (final id in ids)
              if (id != me && profiles[id] != null) profiles[id]!,
          ];
          return GroupConversationView(
            id: c['id'] as String,
            title: (c['title'] ?? 'Group').toString(),
            imageUrl: c['image_url'] as String?,
            others: others,
            memberCount: ids.length,
            lastMessage: lastByGroup[c['id']],
            lastMessageAt:
                DateTime.parse(c['last_message_at'].toString()).toLocal(),
          );
        }(),
    ];
  }

  /// The member id → profile map for one group (used to label senders).
  Future<Map<String, Profile>> members(String groupId) async {
    final rows = await SupabaseConfig.db
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    final ids = [for (final r in rows as List) (r as Map)['user_id'] as String];
    return _profilesByIds(ids);
  }

  Future<Map<String, Profile>> _profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows =
        await SupabaseConfig.db.from('profiles').select().inFilter('id', ids);
    return {
      for (final p in rows as List)
        (p as Map<String, dynamic>)['id'] as String: Profile.fromMap(p),
    };
  }

  /// Create a group with [title] and [memberIds] (matches). Returns its id.
  Future<String?> createGroup(String title, List<String> memberIds) async {
    final res = await SupabaseConfig.db.rpc(
      'create_group_conversation',
      params: {'title': title, 'members': memberIds},
    );
    return res?.toString();
  }

  Future<List<GroupMessage>> messages(String groupId) async {
    final rows = await SupabaseConfig.db
        .from('group_messages')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true);
    return [
      for (final m in rows as List)
        GroupMessage.fromMap(m as Map<String, dynamic>)
    ];
  }

  /// Realtime stream of a group's messages (ordered).
  Stream<List<GroupMessage>> messageStream(String groupId) {
    // The Supabase stream builder's order() defaults to DESCENDING, so request
    // ascending explicitly AND sort in Dart — realtime inserts must stay
    // oldest→newest (else the newest bubble renders at the top, not the bottom).
    return SupabaseConfig.db
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(GroupMessage.fromMap).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  Future<void> send({
    required String groupId,
    required String body,
    String? translatedBody,
    String? sourceLang,
    String? targetLang,
    String? imageUrl,
  }) async {
    final me = myId;
    if (me == null) return;
    await SupabaseConfig.db.from('group_messages').insert({
      'group_id': groupId,
      'sender_id': me,
      'body': body,
      'translated_body': ?translatedBody,
      'source_lang': ?sourceLang,
      'target_lang': ?targetLang,
      'image_url': ?imageUrl,
    });
  }

  /// Upload a group-chat image to the sender's folder in the public `chat` bucket.
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

  /// Demo-only: a random other member posts a canned reply.
  Future<void> demoAutoreply(String groupId) async {
    await SupabaseConfig.db
        .rpc('group_demo_autoreply', params: {'grp': groupId});
  }

  /// Leave the group (remove my membership row).
  Future<void> leave(String groupId) async {
    final me = myId;
    if (me == null) return;
    await SupabaseConfig.db
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', me);
  }
}
