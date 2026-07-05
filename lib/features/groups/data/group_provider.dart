import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_provider.dart';
import '../../discover/data/profile_models.dart';
import 'group_models.dart';
import 'group_repository.dart';

final groupRepositoryProvider =
    Provider<GroupRepository>((_) => GroupRepository());

/// The current user's group conversations (newest first).
final groupsProvider = FutureProvider<List<GroupConversationView>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(groupRepositoryProvider).groups();
});

/// Live messages for a group.
final groupMessagesStreamProvider =
    StreamProvider.family<List<GroupMessage>, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).messageStream(groupId);
});

/// Member id → profile map for a group (labels senders in the thread).
final groupMembersProvider =
    FutureProvider.family<Map<String, Profile>, String>((ref, groupId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(groupRepositoryProvider).members(groupId);
});
