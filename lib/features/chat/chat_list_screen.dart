import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../groups/create_group_screen.dart';
import '../groups/data/group_models.dart';
import '../groups/data/group_provider.dart';
import '../groups/group_thread_screen.dart';
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
    final groups = ref.watch(groupsProvider).asData?.value ??
        const <GroupConversationView>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.usersRound),
            tooltip: 'New group',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: 'Search',
            onPressed: (convos.isEmpty && groups.isEmpty)
                ? null
                : () => showSearch(
                      context: context,
                      delegate:
                          _ChatSearchDelegate(convos: convos, groups: groups),
                    ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          ref.invalidate(matchesProvider);
          ref.invalidate(groupsProvider);
        },
        child: Column(
          children: [
            if (matches.isNotEmpty) _NewMatchesStrip(matches: matches),
            if (matches.isNotEmpty) const Divider(height: 1),
            Expanded(
              child: convosAsync.isLoading && groups.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : convos.isEmpty && groups.isEmpty
                      ? const _NoConversations()
                      : ListView(
                          children: [
                            if (groups.isNotEmpty) ...[
                              const _SectionLabel('Groups'),
                              for (final g in groups) _GroupTile(view: g),
                              if (convos.isNotEmpty)
                                const _SectionLabel('Direct messages'),
                            ],
                            for (var i = 0; i < convos.length; i++) ...[
                              if (i > 0)
                                const Divider(height: 1, indent: 84),
                              _ConversationTile(view: convos[i]),
                            ],
                          ],
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

/// Search across direct conversations + groups by name/title.
class _ChatSearchDelegate extends SearchDelegate<void> {
  final List<ConversationView> convos;
  final List<GroupConversationView> groups;
  _ChatSearchDelegate({required this.convos, required this.groups});

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final gMatches = [
      for (final g in groups)
        if (q.isEmpty || g.title.toLowerCase().contains(q)) g,
    ];
    final cMatches = [
      for (final c in convos)
        if (q.isEmpty || c.other.name.toLowerCase().contains(q)) c,
    ];
    if (gMatches.isEmpty && cMatches.isEmpty) {
      return const Center(child: Text('No matches'));
    }
    return ListView(
      children: [
        for (final g in gMatches)
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.usersRound,
                  color: Colors.white, size: 18),
            ),
            title: Text(g.title),
            subtitle: Text('${g.memberCount} members'),
            onTap: () {
              close(context, null);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      GroupThreadScreen(groupId: g.id, title: g.title)));
            },
          ),
        for (final c in cMatches)
          ListTile(
            leading: ProfileAvatar(
              photoUrl: c.other.photoUrl,
              initial: c.other.initial,
              colorA: c.other.colorA,
              colorB: c.other.colorB,
              size: 44,
            ),
            title: Text(c.other.name),
            onTap: () {
              close(context, null);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatThreadScreen(profile: c.other)));
            },
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  final GroupConversationView view;
  const _GroupTile({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final myId = ref.watch(groupRepositoryProvider).myId;
    final last = view.lastMessage;
    final mineLast = last?.mine(myId) ?? false;
    final preview = last != null
        ? (mineLast ? 'You: ${last.body}' : last.body)
        : '${view.memberCount} members · say hi 👋';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.usersRound, color: Colors.white),
      ),
      title: Text(view.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.outline),
      ),
      trailing: Text(_shortTime(view.lastMessageAt),
          style: TextStyle(fontSize: 12, color: cs.outline)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GroupThreadScreen(groupId: view.id, title: view.title),
        ),
      ),
    );
  }
}
