import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/error_retry.dart';
import '../../core/widgets/skeleton.dart';
import '../stories/data/stories_provider.dart';
import '../stories/widgets/stories_bar.dart';
import 'compose_post_screen.dart';
import 'data/timeline_models.dart';
import 'data/timeline_provider.dart';
import 'widgets/post_card.dart';

/// The social timeline — a Facebook-style feed of member posts.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scroll = ScrollController();

  // Pulse value acknowledged (loaded) — if the live pulse is ahead, new posts
  // have arrived and we show the "New posts" pill.
  int _seenPulse = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load the next page as the user nears the bottom (infinite scroll).
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 600) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _loadNewPosts() {
    _seenPulse = ref.read(feedPulseProvider).asData?.value ?? _seenPulse;
    ref.invalidate(feedProvider);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedProvider);
    final reachedEnd = ref.watch(feedProvider.notifier).reachedEnd;
    final pulse = ref.watch(feedPulseProvider).asData?.value ?? 0;
    // A fresh feed load resets the baseline; a later pulse means new posts.
    final hasNew = pulse > _seenPulse;
    // When the feed (re)loads, sync the baseline so the pill hides.
    ref.listen(feedProvider, (_, next) {
      next.whenData((_) {
        final p = ref.read(feedPulseProvider).asData?.value ?? 0;
        if (_seenPulse != p) setState(() => _seenPulse = p);
      });
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandWordmark(fontSize: 24),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openCompose,
        child: const Icon(LucideIcons.penLine),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          ref.invalidate(storiesProvider);
        },
        child: feedAsync.when(
          loading: () => ListView(
            children: const [
              StoriesBar(),
              SkeletonList(itemCount: 4, itemHeight: 260),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              const StoriesBar(),
              const SizedBox(height: 40),
              ErrorRetry(
                message: 'Feed unavailable.',
                onRetry: () => ref.invalidate(feedProvider),
              ),
            ],
          ),
          data: (posts) {
            // Trailing slot: a loader while more pages may exist (and there's
            // at least one post to page from).
            final showLoader = posts.isNotEmpty && !reachedEnd;
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.only(top: 6, bottom: 88),
              itemCount: posts.length + 2 + (showLoader ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == 0) return const StoriesBar();
                if (i == 1) {
                  return posts.isEmpty
                      ? _EmptyFeedBody(onCompose: _openCompose)
                      : _ComposePrompt(onTap: _openCompose);
                }
                if (i == posts.length + 2) {
                  // Trailing loader.
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                return _PostCardEntry(post: posts[i - 2]);
              },
            );
          },
        ),
          ),
          // "New posts" pill — appears when a post lands while you're browsing.
          if (hasNew)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _loadNewPosts,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.arrowUp,
                              color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('New posts',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openCompose() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ComposePostScreen()),
    );
    if (posted == true) ref.invalidate(feedProvider);
  }
}

/// Isolate each card's rebuild scope (like state) from the list.
class _PostCardEntry extends StatelessWidget {
  final Post post;
  const _PostCardEntry({required this.post});

  @override
  Widget build(BuildContext context) => PostCard(key: ValueKey(post.id), post: post);
}

class _ComposePrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposePrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.penLine, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('Share something…',
                    style: TextStyle(color: cs.outline)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeedBody extends StatelessWidget {
  final VoidCallback onCompose;
  const _EmptyFeedBody({required this.onCompose});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      child: Column(
        children: [
              Icon(LucideIcons.newspaper, size: 56, color: cs.outline),
              const SizedBox(height: 16),
              Text('Your feed is empty',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Be the first to share something with the community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.outline)),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: GradientButton(
                  label: 'Create a post',
                  icon: LucideIcons.penLine,
                  onPressed: onCompose,
                ),
              ),
        ],
      ),
    );
  }
}
