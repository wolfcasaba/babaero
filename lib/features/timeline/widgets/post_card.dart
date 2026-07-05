import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/data/auth_provider.dart';
import '../../chat/data/translation_service.dart';
import '../../safety/data/safety_provider.dart';
import '../data/timeline_models.dart';
import '../data/timeline_provider.dart';
import 'comments_sheet.dart';

String postTimeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}

/// One feed card. Holds local like state (optimistic) + an on-demand
/// translation toggle for the post text, mirroring the chat translation UX.
class PostCard extends ConsumerStatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _liked = widget.post.likedByMe;
  late int _likeCount = widget.post.likeCount;
  bool _busy = false;

  /// Bumped on each double-tap-to-like so the heart-burst overlay restarts.
  int _burstTick = 0;

  String? _translation;
  bool _translating = false;
  bool _showTranslation = false;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    // The card State is reused across feed refreshes (keyed by post id), so
    // re-sync the optimistic like state from the fresh post — otherwise a
    // server-corrected count or a like made elsewhere would stay stale. Skip
    // while a like write is in flight so we don't clobber the optimistic value.
    if (!_busy && old.post.id == widget.post.id) {
      if (widget.post.likedByMe != old.post.likedByMe) {
        _liked = widget.post.likedByMe;
      }
      if (widget.post.likeCount != old.post.likeCount) {
        _likeCount = widget.post.likeCount;
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    try {
      await ref.read(timelineRepositoryProvider).setLiked(widget.post.id, _liked);
    } catch (_) {
      // Revert on failure so the UI never lies about persistence.
      if (mounted) {
        setState(() {
          _liked = !_liked;
          _likeCount += _liked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Double-tap the photo to like (the universal social gesture) — likes if
  /// not already liked and fires a heart-burst overlay each tap.
  void _likeFromDoubleTap() {
    HapticFeedback.mediumImpact();
    setState(() => _burstTick++);
    if (!_liked && !_busy) _toggleLike();
  }

  Future<void> _toggleTranslation() async {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
      return;
    }
    if (_translation != null) {
      setState(() => _showTranslation = true);
      return;
    }
    setState(() => _translating = true);
    try {
      final out = await translationService.toCounterpart(widget.post.content);
      if (!mounted) return;
      setState(() {
        _translation = out == widget.post.content ? null : out;
        _showTranslation = _translation != null;
      });
    } catch (_) {
      // ignore — leave translation unavailable
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => CommentsSheet(post: widget.post),
    ).then((_) => ref.invalidate(feedProvider));
  }

  Future<void> _share() async {
    final text = widget.post.content;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post copied to clipboard')),
      );
    }
  }

  Future<void> _openMenu() async {
    final myId = ref.read(currentUserIdProvider);
    final mine = myId != null && myId == widget.post.author.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: const Text('Copy text'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            if (mine)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: AppColors.danger),
                title: const Text('Delete post'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else
              ListTile(
                leading: const Icon(LucideIcons.flag, color: AppColors.secondary),
                title: const Text('Report post'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (action) {
      case 'copy':
        await _share();
      case 'delete':
        await _confirmDelete();
      case 'report':
        await _report();
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This permanently removes your post.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(timelineRepositoryProvider).deletePost(widget.post.id);
      ref.invalidate(feedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    }
  }

  Future<void> _report() async {
    const reasons = [
      'Spam',
      'Inappropriate content',
      'Harassment or abuse',
      'Scam',
      'Something else',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in reasons)
              ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await ref.read(safetyRepositoryProvider).report(
            widget.post.author.id,
            reason: 'Post: $reason',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks — we\'ll review this post.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send report. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.post;
    final location = [p.author.city, p.author.country]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Row(
              children: [
                Stack(
                  children: [
                    ProfileAvatar(
                      photoUrl: p.author.photoUrl,
                      initial: p.author.initial,
                      colorA: p.author.colorA,
                      colorB: p.author.colorB,
                      size: 44,
                    ),
                    if (p.author.online)
                      const Positioned(
                          bottom: 0, right: 0, child: OnlineDot(size: 11)),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.author.name.isEmpty ? 'Member' : p.author.name,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.author.verified) ...[
                            const SizedBox(width: 5),
                            const VerifiedBadge(size: 14),
                          ],
                        ],
                      ),
                      Text(
                        [
                          if (location.isNotEmpty) location,
                          postTimeAgo(p.createdAt),
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.ellipsis, size: 20),
                  tooltip: 'More',
                  onPressed: _openMenu,
                ),
              ],
            ),
          ),

          // Text + translation toggle.
          if (p.content.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.content, style: const TextStyle(fontSize: 15, height: 1.35)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _translating ? null : _toggleTranslation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.languages,
                              size: 13, color: AppColors.secondary),
                          const SizedBox(width: 5),
                          Text(
                            _translating
                                ? 'Translating…'
                                : _showTranslation
                                    ? 'Hide translation'
                                    : 'See translation',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showTranslation && _translation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _translation!,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Image.
          if (p.hasImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
              child: GestureDetector(
                onDoubleTap: _likeFromDoubleTap,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CachedNetworkImage(
                      imageUrl: p.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 250),
                      placeholder: (_, _) => const Skeleton(height: 220),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                    if (_burstTick > 0)
                      Icon(LucideIcons.heart,
                              size: 100,
                              color: Colors.white.withValues(alpha: 0.92))
                          .animate(key: ValueKey(_burstTick))
                          .scale(
                            begin: const Offset(0.4, 0.4),
                            end: const Offset(1, 1),
                            duration: 260.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(duration: 120.ms)
                          .then(delay: 260.ms)
                          .fadeOut(duration: 260.ms),
                  ],
                ),
              ),
            ),

          // Counts row.
          if (_likeCount > 0 || p.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  if (_likeCount > 0) ...[
                    const Icon(LucideIcons.heart,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('$_likeCount',
                        style: TextStyle(fontSize: 12.5, color: cs.outline)),
                  ],
                  const Spacer(),
                  if (p.commentCount > 0)
                    Text('${p.commentCount} comments',
                        style: TextStyle(fontSize: 12.5, color: cs.outline)),
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(height: 16),
          ),

          // Actions.
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: LucideIcons.heart,
                    label: 'Like',
                    active: _liked,
                    onTap: _toggleLike,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: LucideIcons.messageCircle,
                    label: 'Comment',
                    onTap: _openComments,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: LucideIcons.share2,
                    label: 'Share',
                    onTap: _share,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppColors.primary : Theme.of(context).colorScheme.outline;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
