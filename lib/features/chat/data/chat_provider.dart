import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../auth/data/auth_provider.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((_) => ChatRepository());

/// App-level realtime pulse: emits a tick whenever a direct or group message is
/// inserted/updated anywhere the current user can see. Lets the conversation
/// list + unread badges refresh LIVE (not only on pull-to-refresh / thread
/// open). Cheap — it carries no row data, just a signal to refetch.
final messagePulseProvider = StreamProvider<int>((ref) {
  if (!SupabaseConfig.isConfigured || !SupabaseConfig.isSignedIn) {
    return const Stream<int>.empty();
  }
  final controller = StreamController<int>();
  var tick = 0;
  void bump(PostgresChangePayload _) => controller.add(++tick);

  final channel = SupabaseConfig.client
      .channel('inbox-pulse')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'babaero',
        table: 'messages',
        callback: bump,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'babaero',
        table: 'messages',
        callback: bump,
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'babaero',
        table: 'group_messages',
        callback: bump,
      )
      .subscribe();

  ref.onDispose(() {
    SupabaseConfig.client.removeChannel(channel);
    controller.close();
  });
  return controller.stream;
});

/// The current user's conversation list (newest first). Refetches live on each
/// message pulse so unread counts + previews stay current across the app.
final conversationsProvider = FutureProvider<List<ConversationView>>((ref) {
  ref.watch(currentUserIdProvider);
  ref.watch(messagePulseProvider);
  return ref.watch(chatRepositoryProvider).conversations();
});

/// Live messages for a conversation.
final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).messageStream(conversationId);
});

/// Total unread direct-message count across all conversations — drives the
/// badge on the Messages bottom-nav tab.
final unreadTotalProvider = Provider<int>((ref) {
  final convos = ref.watch(conversationsProvider).asData?.value;
  if (convos == null) return 0;
  var total = 0;
  for (final c in convos) {
    total += c.unreadCount;
  }
  return total;
});
