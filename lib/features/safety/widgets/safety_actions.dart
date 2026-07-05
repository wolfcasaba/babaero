import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../data/safety_provider.dart';

/// Shared block/report bottom-sheet flow, reachable from the profile detail
/// screen and from inside a chat thread (so a user can act from where abuse
/// happens). Returns true if the target was blocked — callers can then pop /
/// refresh. Invalidating [blockedIdsProvider] cascades to Discover, Matches,
/// the conversation list and the feed (they all watch it), so a block takes
/// effect everywhere at once.
Future<bool> showSafetyActions(
  BuildContext context,
  WidgetRef ref, {
  required String targetId,
  required String targetName,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.flag, color: AppColors.secondary),
            title: Text('Report $targetName'),
            subtitle: const Text("Tell us what's wrong"),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
          ListTile(
            leading: const Icon(LucideIcons.ban, color: AppColors.danger),
            title: Text('Block $targetName'),
            subtitle: const Text('They can no longer see or message you'),
            onTap: () => Navigator.pop(ctx, 'block'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  if (action == 'report') {
    await _report(context, ref, targetId, targetName);
    return false;
  }
  if (action == 'block') {
    return _block(context, ref, targetId, targetName);
  }
  return false;
}

Future<void> _report(
    BuildContext context, WidgetRef ref, String id, String name) async {
  const reasons = [
    'Fake profile',
    'Inappropriate photos',
    'Harassment or abuse',
    'Scam or spam',
    'Underage',
    'Something else',
  ];
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Why are you reporting?',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          for (final r in reasons)
            ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  try {
    await ref.read(safetyRepositoryProvider).report(id, reason: reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks — we'll review this report.")),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send report. Try again.')),
      );
    }
  }
}

Future<bool> _block(
    BuildContext context, WidgetRef ref, String id, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
          "They won't appear anywhere for you and can't message you. You can "
          'unblock later from Safety & privacy.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Block', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(safetyRepositoryProvider).block(id);
    // One invalidation cascades to every surface that watches blockedIds.
    ref.invalidate(blockedIdsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name blocked.')),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not block. Try again.')),
      );
    }
    return false;
  }
}
