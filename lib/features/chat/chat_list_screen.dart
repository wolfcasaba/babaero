import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../matches/data/matches_provider.dart';
import 'chat_thread_screen.dart';
import 'data/chat_models.dart';
import 'data/chat_provider.dart';

String _shortTime(DateTime t) {
  final now = DateTime.now();
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays == 1) return 'Yesterday';
  return '${d.inDays}d';
}

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosAsync = ref.watch(conversationsProvider);
    final matches = ref.watch(matchesProvider).asData?.value ?? const <Profile>[];
    final convos = convosAsync.asData?.value ?? const <ConversationView>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.search), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          ref.invalidate(matchesProvider);
        },
        child: Column(
          children: [
            if (matches.isNotEmpty) _NewMatchesStrip(matches: matches),
            if (matches.isNotEmpty) const Divider(height: 1),
            Expanded(
              child: convosAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : convos.isEmpty
                      ? const _NoConversations()
                      : ListView.separated(
                          itemCount: convos.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, indent: 84),
                          itemBuilder: (_, i) =>
                              _ConversationTile(view: convos[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoConversations extends StatelessWidget {
  const _NoConversations();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Column(
            children: [
              Icon(LucideIcons.messageCircle, size: 56, color: cs.outline),
              const SizedBox(height: 16),
              Text('No messages yet',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Match with someone and say hi — your chats appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.outline)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewMatchesStrip extends StatelessWidget {
  final List<Profile> matches;
  const _NewMatchesStrip({required this.matches});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: matches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final p = matches[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatThreadScreen(profile: p),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    ProfileAvatar(
                      photoUrl: p.photoUrl,
                      initial: p.initial,
                      colorA: p.colorA,
                      colorB: p.colorB,
                      size: 60,
                    ),
                    if (p.online)
                      const Positioned(bottom: 2, right: 2, child: OnlineDot()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(p.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationView view;
  const _ConversationTile({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final myId = ref.watch(chatRepositoryProvider).myId;
    final last = view.lastMessage;
    final preview = last?.body ?? 'You matched — say hi! 👋';
    final mineLast = last?.mine(myId) ?? false;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          ProfileAvatar(
            photoUrl: view.other.photoUrl,
            initial: view.other.initial,
            colorA: view.other.colorA,
            colorB: view.other.colorB,
            size: 56,
          ),
          if (view.other.online)
            const Positioned(bottom: 0, right: 0, child: OnlineDot()),
        ],
      ),
      title: Row(
        children: [
          Text(view.other.name,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          if (view.other.verified) ...[
            const SizedBox(width: 5),
            const VerifiedBadge(size: 15),
          ],
        ],
      ),
      subtitle: Text(
        mineLast ? 'You: $preview' : preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.outline),
      ),
      trailing: Text(_shortTime(view.lastMessageAt),
          style: TextStyle(fontSize: 12, color: cs.outline)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(profile: view.other),
        ),
      ),
    );
  }
}
