import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../chat/data/chat_provider.dart';
import '../chat/data/translation_service.dart';
import 'data/stories_models.dart';
import 'data/stories_provider.dart';

/// Full-screen story viewer. Auto-advances through each author's stories with
/// progress bars; tap right/left to skip, tap the X to close.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final List<StoryGroup> groups;
  final int startGroup;
  const StoryViewerScreen({
    super.key,
    required this.groups,
    this.startGroup = 0,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _perStory = Duration(seconds: 5);
  late final AnimationController _c =
      AnimationController(vsync: this, duration: _perStory);
  late int _group = widget.startGroup;
  int _story = 0;

  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
    // Pause the auto-advance while the viewer is composing a reply.
    _replyFocus.addListener(() {
      if (_replyFocus.hasFocus) {
        _c.stop();
      } else if (!_c.isAnimating) {
        _c.forward();
      }
    });
    _start();
  }

  @override
  void dispose() {
    _reply.dispose();
    _replyFocus.dispose();
    _c.dispose();
    super.dispose();
  }

  StoryGroup get _g => widget.groups[_group];
  Story get _s => _g.stories[_story];

  void _start() {
    _c.forward(from: 0);
    ref.read(storyRepositoryProvider).markViewed(_s.id);
  }

  void _next() {
    if (_story < _g.stories.length - 1) {
      setState(() => _story++);
      _start();
    } else if (_group < widget.groups.length - 1) {
      setState(() {
        _group++;
        _story = 0;
      });
      _start();
    } else {
      ref.invalidate(storiesProvider);
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_story > 0) {
      setState(() => _story--);
      _start();
    } else if (_group > 0) {
      setState(() {
        _group--;
        _story = 0;
      });
      _start();
    } else {
      _c.forward(from: 0);
    }
  }

  /// Send a reply / quick reaction to the story's author as a direct message.
  /// Resolves (or creates) the 1:1 conversation, translates text replies (skips
  /// pure-emoji reactions), and lands it in the normal chat thread.
  Future<void> _sendStoryReply(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sendingReply) return;
    setState(() => _sendingReply = true);
    final name = _g.author.name;
    final repo = ref.read(chatRepositoryProvider);
    try {
      final convId = await repo.getOrCreateConversationWith(_g.author.id);
      if (convId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't send — please try again.")),
          );
        }
        return;
      }
      String? src;
      String? target;
      String? translated;
      // Translate real text; a lone emoji reaction needs no translation.
      if (_hasLetters(text)) {
        src = translationService.detect(text);
        target = src == 'tl' ? 'en' : 'tl';
        translated = await translationService.translate(text, target: target);
      }
      await repo.send(
        conversationId: convId,
        body: text,
        translatedBody:
            (translated != null && translated != text) ? translated : null,
        sourceLang: src,
        targetLang: target,
      );
      // Surface the new/updated conversation in the Messages list + badge.
      ref.invalidate(conversationsProvider);
      if (mounted) {
        _reply.clear();
        _replyFocus.unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent to $name 💬')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send — please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  static bool _hasLetters(String s) => RegExp(r'[A-Za-z]').hasMatch(s);

  @override
  Widget build(BuildContext context) {
    final author = _g.author;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w * 0.33) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressDown: (_) => _c.stop(),
        onLongPressUp: () => _c.forward(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media.
            Container(color: Colors.black),
            if (_s.imageUrl.isNotEmpty)
              Center(
                child: CachedNetworkImage(
                  imageUrl: _s.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, _) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // Top scrim for legibility.
            const Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Progress bars.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Row(
                      children: [
                        for (var i = 0; i < _g.stories.length; i++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: _ProgressBar(
                                controller: _c,
                                state: i < _story
                                    ? 1
                                    : i == _story
                                        ? 2
                                        : 0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Header.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          photoUrl: author.photoUrl,
                          initial: author.initial,
                          colorA: author.colorA,
                          colorB: author.colorB,
                          size: 38,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _g.isMine ? 'Your story' : author.name,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white),
                          onPressed: () {
                            ref.invalidate(storiesProvider);
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Caption + reply bar, lifted above the keyboard when composing.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_s.caption != null && _s.caption!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14, left: 4),
                          child: Text(
                            _s.caption!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
                          ),
                        ),
                      // No replying to your own story.
                      if (!_g.isMine) _StoryReplyBar(
                        authorName: author.name,
                        controller: _reply,
                        focusNode: _replyFocus,
                        sending: _sendingReply,
                        onReact: _sendStoryReply,
                        onSend: () => _sendStoryReply(_reply.text),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The reply composer at the bottom of a story: a row of one-tap emoji
/// reactions + a text field that sends a direct message to the story's author.
class _StoryReplyBar extends StatelessWidget {
  final String authorName;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ValueChanged<String> onReact;
  final VoidCallback onSend;

  const _StoryReplyBar({
    required this.authorName,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onReact,
    required this.onSend,
  });

  static const _reactions = ['❤️', '🔥', '😂', '😮', '👍', '🙌'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _reactions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final emoji = _reactions[i];
              return GestureDetector(
                onTap: sending ? null : () => onReact(emoji),
                child: Container(
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !sending,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Reply to $authorName…',
                  hintStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.send,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final AnimationController controller;

  /// 0 = upcoming (empty), 1 = done (full), 2 = active (animated).
  final int state;
  const _ProgressBar({required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: state == 2
            ? AnimatedBuilder(
                animation: controller,
                builder: (_, _) => LinearProgressIndicator(
                  value: controller.value,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : ColoredBox(
                color: state == 1 ? Colors.white : Colors.white24,
                child: const SizedBox(width: double.infinity),
              ),
      ),
    );
  }
}
