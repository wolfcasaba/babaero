import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/brand_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
    _start();
  }

  @override
  void dispose() {
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
            // Caption.
            if (_s.caption != null && _s.caption!.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    _s.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
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
