import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import 'data/chat_models.dart';
import 'data/chat_provider.dart';
import 'data/translation_service.dart';

/// A 1:1 conversation. Resolves (or creates) the conversation, streams its
/// messages in realtime, and translates outgoing text on send.
class ChatThreadScreen extends ConsumerStatefulWidget {
  final Profile profile;
  const ChatThreadScreen({super.key, required this.profile});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _conversationId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _resolveConversation();
  }

  Future<void> _resolveConversation() async {
    final id = await ref
        .read(chatRepositoryProvider)
        .getOrCreateConversationWith(widget.profile.id);
    if (mounted) setState(() => _conversationId = id);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final convId = _conversationId;
    if (text.isEmpty || convId == null || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      final src = translationService.detect(text);
      final target = src == 'tl' ? 'en' : 'tl';
      final translated =
          await translationService.translate(text, target: target);
      final repo = ref.read(chatRepositoryProvider);
      await repo.send(
        conversationId: convId,
        body: text,
        translatedBody: translated == text ? null : translated,
        sourceLang: src,
        targetLang: target,
      );
      // Demo liveliness: the other person replies shortly after.
      Future.delayed(const Duration(milliseconds: 1400), () {
        repo.demoAutoreply(convId);
      });
    } catch (_) {
      // ignore — realtime will reconcile
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.profile;
    final myId = ref.watch(chatRepositoryProvider).myId;
    final convId = _conversationId;

    final messagesAsync = convId == null
        ? const AsyncValue<List<Message>>.loading()
        : ref.watch(messagesStreamProvider(convId));
    messagesAsync.whenData((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                ProfileAvatar(
                  photoUrl: p.photoUrl,
                  initial: p.initial,
                  colorA: p.colorA,
                  colorB: p.colorB,
                  size: 40,
                ),
                if (p.online)
                  const Positioned(
                      bottom: 0, right: 0, child: OnlineDot(size: 10)),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(p.name,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    if (p.verified) ...[
                      const SizedBox(width: 5),
                      const VerifiedBadge(size: 14),
                    ],
                  ],
                ),
                Text(
                  p.online ? 'Online now' : 'Active recently',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.online ? AppColors.online : cs.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(LucideIcons.video), onPressed: () {}),
          IconButton(icon: const Icon(LucideIcons.phone), onPressed: () {}),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const _TranslationBanner(),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Chat unavailable.\n$e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyThread(name: p.name);
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) =>
                      _Bubble(msg: messages[i], mine: messages[i].mine(myId)),
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            enabled: convId != null && !_sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _TranslationBanner extends StatelessWidget {
  const _TranslationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.secondary.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.languages,
              size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-translation on · Tagalog ↔ English',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  final String name;
  const _EmptyThread({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, size: 44, color: AppColors.accent),
            const SizedBox(height: 14),
            Text('Say hello to $name 👋',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Type in your language — we translate it automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message msg;
  final bool mine;
  const _Bubble({required this.msg, required this.mine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Show the translation under non-English (incoming Tagalog) messages.
    final showTranslation = msg.translatedBody != null &&
        msg.translatedBody!.isNotEmpty &&
        translationService.detect(msg.body) == 'tl';
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    return Container(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: mine ? AppColors.brandGradient : null,
              color: mine ? null : cs.surfaceContainerHighest,
              borderRadius: radius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.body,
                  style: TextStyle(
                    color: mine ? Colors.white : cs.onSurface,
                    fontSize: 15,
                  ),
                ),
                if (showTranslation) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                      height: 1,
                      color: (mine ? Colors.white : cs.onSurface)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.languages,
                          size: 12,
                          color: (mine ? Colors.white : cs.onSurface)
                              .withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          msg.translatedBody!,
                          style: TextStyle(
                            color: (mine ? Colors.white : cs.onSurface)
                                .withValues(alpha: 0.85),
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(_time(msg.createdAt),
                style: TextStyle(fontSize: 11, color: cs.outline)),
          ),
        ],
      ),
    );
  }

  String _time(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.plus),
              color: AppColors.primary,
              onPressed: enabled ? () {} : null,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: enabled ? onSend : null,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.send,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
