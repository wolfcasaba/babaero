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
