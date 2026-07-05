import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_provider.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((_) => ChatRepository());

/// The current user's conversation list (newest first).
final conversationsProvider = FutureProvider<List<ConversationView>>((ref) {
  ref.watch(currentUserIdProvider);
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
