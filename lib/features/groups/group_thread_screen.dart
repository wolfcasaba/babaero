import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../chat/data/translation_service.dart';
import '../chat/widgets/message_widgets.dart';
import '../discover/data/profile_models.dart';
import '../settings/data/app_settings.dart';
import 'data/group_provider.dart';

/// A group conversation. Streams its messages in realtime, labels each incoming
/// message with the sender's name/avatar, and translates outgoing text on send.
class GroupThreadScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String title;
  const GroupThreadScreen({
    super.key,
    required this.groupId,
    required this.title,
  });

  @override
  ConsumerState<GroupThreadScreen> createState() => _GroupThreadScreenState();
}

class _GroupThreadScreenState extends ConsumerState<GroupThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
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
      final repo = ref.read(groupRepositoryProvider);
      await repo.send(
        groupId: widget.groupId,
        body: text,
        translatedBody:
            (translated != null && translated != text) ? translated : null,
        sourceLang: src,
        targetLang: target,
      );
      // Demo liveliness: another member replies shortly after.
      Future.delayed(const Duration(milliseconds: 1400), () {
        repo.demoAutoreply(widget.groupId);
      });
    } catch (_) {
      // ignore — realtime will reconcile
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sending) return;
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final repo = ref.read(groupRepositoryProvider);
      final url = await repo.uploadImage(bytes, ext: ext == 'png' ? 'png' : 'jpg');
      if (url != null) {
        await repo.send(groupId: widget.groupId, body: '', imageUrl: url);
        Future.delayed(const Duration(milliseconds: 1400), () {
          repo.demoAutoreply(widget.groupId);
        });
      }
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
    final myId = ref.watch(groupRepositoryProvider).myId;
    final messagesAsync = ref.watch(groupMessagesStreamProvider(widget.groupId));
    final members =
        ref.watch(groupMembersProvider(widget.groupId)).asData?.value ??
            const <String, Profile>{};
    messagesAsync.whenData((_) => _scrollToBottom());

    final memberCount = members.isEmpty ? null : members.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.usersRound,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    memberCount == null ? 'Group' : '$memberCount members',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.video),
            tooltip: 'Group video call',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Calls are coming soon.')),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const TranslationBanner(),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Chat unavailable.\n$e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const _EmptyThread();
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final mine = m.mine(myId);
                    // Show the sender header when the previous message was from
                    // someone else (groups the run of one person's messages).
                    final showSender = !mine &&
                        (i == 0 || messages[i - 1].senderId != m.senderId);
                    return MessageBubble(
                      mine: mine,
                      body: m.body,
                      translatedBody: m.translatedBody,
                      imageUrl: m.imageUrl,
                      createdAt: m.createdAt,
                      inGroup: true,
                      sender: mine ? null : members[m.senderId],
                      showSender: showSender,
                      maxWidthFactor: 0.70,
                    );
                  },
                );
              },
            ),
          ),
          MessageComposer(
            controller: _input,
            enabled: !_sending,
            onSend: _send,
            hintText: 'Message the group…',
            onAttach: _sending ? null : _pickAndSendImage,
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

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
            Text('Say hello to the group 👋',
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
