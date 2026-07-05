import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../settings/data/app_settings.dart';
import 'data/chat_models.dart';
import 'data/chat_provider.dart';
import 'data/translation_service.dart';
import 'data/typing_channel.dart';
import 'widgets/message_widgets.dart';

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

  // Newest incoming message we've already marked read — avoids re-firing the
  // mark-read RPC on every stream tick.
  String? _lastReadMsgId;

  // Realtime typing indicator (created once the conversation id resolves).
  TypingChannel? _typing;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTyping);
    _resolveConversation();
  }

  Future<void> _resolveConversation() async {
    final id = await ref
        .read(chatRepositoryProvider)
        .getOrCreateConversationWith(widget.profile.id);
    if (!mounted) return;
    setState(() => _conversationId = id);
    if (id != null) {
      _typing = TypingChannel(id)..connect();
    }
  }

  void _onTyping() {
    if (_input.text.trim().isNotEmpty) _typing?.notifyTyping();
  }

  /// App-bar subtitle: "typing…" (accent) while the other person types, else the
  /// online / active-recently presence line.
  Widget _statusLine(ColorScheme cs, {required bool typing}) {
    if (typing) {
      return Text(
        'typing…',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.secondary,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final online = widget.profile.online;
    return Text(
      online ? 'Online now' : 'Active recently',
      style: TextStyle(
        fontSize: 12,
        color: online ? AppColors.online : cs.outline,
      ),
    );
  }

  /// Mark the newest incoming message read (once), then refresh the list so the
  /// unread badges clear. Called from the message stream as data arrives.
  void _markReadUpTo(String convId, List<Message> messages, String? myId) {
    Message? newestIncoming;
    for (final m in messages) {
      if (!m.mine(myId)) newestIncoming = m;
    }
    if (newestIncoming == null || newestIncoming.id == _lastReadMsgId) return;
    final targetId = newestIncoming.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // No-ops gracefully until migration 14 (mark_conversation_read) is
        // applied to the hosted DB.
        await ref.read(chatRepositoryProvider).markRead(convId);
        // Only mark this message as handled AFTER the RPC succeeds, so a failed
        // mark-read retries on the next stream tick instead of sticking unread.
        _lastReadMsgId = targetId;
        ref.invalidate(conversationsProvider);
      } catch (_) {
        // ignore — receipts simply stay unread until the RPC exists / succeeds
      }
    });
  }

  @override
  void dispose() {
    _input.removeListener(_onTyping);
    _typing?.dispose();
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
      final autoTranslate =
          ref.read(appSettingsProvider).value?.autoTranslate ?? true;
      String? src;
      String? target;
      String? translated;
      if (autoTranslate) {
        src = translationService.detect(text);
        target = src == 'tl' ? 'en' : 'tl';
        translated = await translationService.translate(text, target: target);
      }
      final repo = ref.read(chatRepositoryProvider);
      await repo.send(
        conversationId: convId,
        body: text,
        translatedBody:
            (translated != null && translated != text) ? translated : null,
        sourceLang: src,
        targetLang: target,
      );
      // Demo liveliness: on the seed/demo account the other person replies
      // shortly after. Never fires for real members — they chat for real.
      if (SupabaseConfig.isDemoAccount) {
        Future.delayed(const Duration(milliseconds: 1400), () {
          repo.demoAutoreply(convId);
        });
      }
    } catch (_) {
      // ignore — realtime will reconcile
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final convId = _conversationId;
    if (convId == null || _sending) return;
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final repo = ref.read(chatRepositoryProvider);
      final url = await repo.uploadImage(bytes, ext: ext == 'png' ? 'png' : 'jpg');
      if (url != null) {
        await repo.send(conversationId: convId, body: '', imageUrl: url);
        if (SupabaseConfig.isDemoAccount) {
          Future.delayed(const Duration(milliseconds: 1400), () {
            repo.demoAutoreply(convId);
          });
        }
      }
    } catch (_) {
      // ignore — realtime will reconcile
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calls are coming soon.')),
    );
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
                _typing == null
                    ? _statusLine(cs, typing: false)
                    : ValueListenableBuilder<bool>(
                        valueListenable: _typing!.othersTyping,
                        builder: (_, typing, _) => _statusLine(cs, typing: typing),
                      ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.video),
            tooltip: 'Video call',
            onPressed: () => _comingSoon(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.phone),
            tooltip: 'Voice call',
            onPressed: () => _comingSoon(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const TranslationBanner(),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Chat unavailable.\n$e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyThread(
                    profile: p,
                    onPick: (s) {
                      _input.text = s;
                      _input.selection = TextSelection.collapsed(
                          offset: _input.text.length);
                      setState(() {});
                    },
                  );
                }
                if (convId != null) _markReadUpTo(convId, messages, myId);
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    // Newest anchors to the bottom (index 0 with reverse:true),
                    // so a just-sent message sits right above the composer.
                    final m = messages[messages.length - 1 - i];
                    final mine = m.mine(myId);
                    return MessageBubble(
                      mine: mine,
                      body: m.body,
                      translatedBody: m.translatedBody,
                      imageUrl: m.imageUrl,
                      createdAt: m.createdAt,
                      // Receipt only on my own bubbles: ✓ sent, ✓✓ read.
                      readReceipt: mine ? m.isRead : null,
                    );
                  },
                );
              },
            ),
          ),
          MessageComposer(
            controller: _input,
            enabled: convId != null && !_sending,
            onSend: _send,
            hintText: 'Type a message…',
            onAttach: (convId != null && !_sending) ? _pickAndSendImage : null,
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  final Profile profile;
  final ValueChanged<String> onPick;
  const _EmptyThread({required this.profile, required this.onPick});

  List<String> get _icebreakers {
    final p = profile;
    final first =
        p.interests.isNotEmpty ? p.interests.first.toLowerCase() : null;
    return [
      'Hi ${p.name}! How\'s your day going? 😊',
      if (first != null)
        'I saw you\'re into $first — what got you into it?'
      else
        'What\'s something that always makes you smile?',
      if (p.city.isNotEmpty)
        'What do you love most about ${p.city}?'
      else
        'What are you looking for here on Babaero?',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          const Icon(LucideIcons.sparkles, size: 44, color: AppColors.accent),
          const SizedBox(height: 14),
          Text('Say hello to ${profile.name} 👋',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Type in your language — we translate it automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline)),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Break the ice',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.outline)),
          ),
          const SizedBox(height: 8),
          for (final idea in _icebreakers)
            _IcebreakerChip(text: idea, onTap: () => onPick(idea)),
        ],
      ),
    );
  }
}

class _IcebreakerChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _IcebreakerChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                const Icon(LucideIcons.arrowRight,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
