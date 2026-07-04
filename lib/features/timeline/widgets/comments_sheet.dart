import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../data/timeline_models.dart';
import '../data/timeline_provider.dart';
import 'post_card.dart';

/// Modal comment thread for a post. Reads via [postCommentsProvider], appends
/// through the repository, then re-fetches.
class CommentsSheet extends ConsumerStatefulWidget {
  final Post post;
  const CommentsSheet({super.key, required this.post});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref
          .read(timelineRepositoryProvider)
          .addComment(widget.post.id, text);
      ref.invalidate(postCommentsProvider(widget.post.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final commentsAsync = ref.watch(postCommentsProvider(widget.post.id));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Comments',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            Expanded(
              child: commentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Comments unavailable.\n$e')),
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.messageCircle,
                                size: 40, color: cs.outline),
                            const SizedBox(height: 10),
                            Text('No comments yet — be the first.',
                                style: TextStyle(color: cs.outline)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (_, i) => _CommentTile(comment: comments[i]),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Write a comment…',
                          fillColor: cs.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _send,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            photoUrl: comment.author.photoUrl,
            initial: comment.author.initial,
            colorA: comment.author.colorA,
            colorB: comment.author.colorB,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.author.name.isEmpty
                              ? 'Member'
                              : comment.author.name,
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (comment.author.verified) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 12),
                      ],
                      const SizedBox(width: 6),
                      Text(postTimeAgo(comment.createdAt),
                          style: TextStyle(fontSize: 11, color: cs.outline)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.content, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
