import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../settings/data/app_settings.dart';
import 'data/chat_models.dart';
import 'data/chat_provider.dart';
import 'data/translation_service.dart';
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

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calls are coming soon.')),
    );
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
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    return MessageBubble(
                      mine: m.mine(myId),
                      body: m.body,
                      translatedBody: m.translatedBody,
                      imageUrl: m.imageUrl,
                      createdAt: m.createdAt,
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
