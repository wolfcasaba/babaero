import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../stories/data/stories_provider.dart';
import '../stories/widgets/stories_bar.dart';
import 'compose_post_screen.dart';
import 'data/timeline_models.dart';
import 'data/timeline_provider.dart';
import 'widgets/post_card.dart';

/// The social timeline — a Facebook-style feed of member posts.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandWordmark(fontSize: 24),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openCompose(context, ref),
        child: const Icon(LucideIcons.penLine),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          ref.invalidate(storiesProvider);
        },
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const StoriesBar(),
              const SizedBox(height: 80),
              Center(child: Text('Feed unavailable.\n$e',
                  textAlign: TextAlign.center)),
            ],
          ),
          data: (posts) {
            return ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 88),
              itemCount: posts.length + 2,
              itemBuilder: (_, i) {
                if (i == 0) return const StoriesBar();
                if (i == 1) {
                  return posts.isEmpty
                      ? _EmptyFeedBody(onCompose: () => _openCompose(context, ref))
                      : _ComposePrompt(onTap: () => _openCompose(context, ref));
                }
                return _PostCardEntry(post: posts[i - 2]);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCompose(BuildContext context, WidgetRef ref) async {
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
