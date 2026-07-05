import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/error_retry.dart';
import '../matches/data/matches_provider.dart';
import '../matches/widgets/match_dialog.dart';
import '../profile/data/profile_provider.dart';
import '../profile/profile_detail_screen.dart';
import 'data/discover_filters.dart';
import 'data/discover_provider.dart';
import 'data/profile_models.dart';
import 'widgets/discover_filter_sheet.dart';
import 'widgets/swipe_deck.dart';

/// The main browse surface — a swipeable card deck with pass / super-like / like
/// actions. Drag right to like, left to pass, up to super-like; the action
/// buttons drive the same fling.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _deck = SwipeDeckController();

  // Guards only the match dialog (not the like itself) so two quick mutual
  // matches don't stack dialogs. Likes fire independently and are never dropped.
  bool _dialogOpen = false;

  // Bumped on a manual "caught up" refresh so the deck re-deals from the top
  // even when the reloaded batch is identical (mock mode / small pools).
  int _deal = 0;

  Future<void> _like(Profile p, {bool superLike = false}) async {
    try {
      final matched = await ref
          .read(matchesRepositoryProvider)
          .like(p.id, superLike: superLike);
      ref.invalidate(matchesProvider);
      ref.invalidate(likesYouCountProvider);
      if (matched && mounted && !_dialogOpen) {
        _dialogOpen = true;
        await showMatchDialog(context, p);
        _dialogOpen = false;
      }
    } catch (_) {
      // The deck already advanced; tell the user the like didn't go through.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your like — try again.')),
        );
      }
    }
  }

  Future<void> _onRewind(Profile p, SwipeAction undone) async {
    // A pass has no backend effect; a like/super-like recorded a row, so undo it.
    if (undone == SwipeAction.like || undone == SwipeAction.superLike) {
      try {
        await ref.read(matchesRepositoryProvider).unlike(p.id);
        ref.invalidate(matchesProvider);
        ref.invalidate(likesYouCountProvider);
        ref.invalidate(likedIdsProvider);
      } catch (_) {
        // best-effort — the card is already back on screen
      }
    }
  }

  void _reload() {
    // A deliberate re-deal: refresh the exclusion sets so freshly liked/blocked
    // members drop out, then rebuild the deck from the top.
    ref.invalidate(likedIdsProvider);
    ref.invalidate(discoverProfilesProvider);
    setState(() => _deal++);
  }

  void _onAction(Profile p, SwipeAction action) {
    switch (action) {
      case SwipeAction.like:
        _like(p);
      case SwipeAction.superLike:
        _like(p, superLike: true);
      case SwipeAction.nope:
        break; // passing needs no backend call
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profilesAsync = ref.watch(discoverProfilesProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const BrandWordmark(fontSize: 24),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(discoverFiltersProvider).activeCount > 0,
              label: Text('${ref.watch(discoverFiltersProvider).activeCount}'),
              child: const Icon(LucideIcons.slidersHorizontal),
            ),
            tooltip: 'Filters',
            onPressed: () => showDiscoverFilterSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const _QuickFilterRow(),
          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetry(
                message: 'Could not load profiles.',
                onRetry: () => ref.invalidate(discoverProfilesProvider),
              ),
              data: (profiles) {
                if (profiles.isEmpty) return const _EmptyDiscover();
                final me = ref.watch(myProfileProvider).asData?.value;
                return SwipeDeck(
                  key: ValueKey('${profiles.first.id}-${profiles.length}-$_deal'),
                  profiles: profiles,
                  me: me,
                  controller: _deck,
                  onAction: _onAction,
                  onRewind: _onRewind,
                  onTapProfile: (p) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileDetailScreen(profile: p),
                    ),
                  ),
                  caughtUp: _CaughtUp(onRefresh: _reload),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: LucideIcons.rotateCcw,
                  label: 'Rewind',
                  color: AppColors.accent,
                  bg: cs.surface,
                  size: 46,
                  onTap: () => _deck.rewind(),
                ),
                const SizedBox(width: 14),
                _ActionButton(
                  icon: LucideIcons.x,
                  label: 'Pass',
                  color: cs.onSurface,
                  bg: cs.surface,
                  size: 60,
                  onTap: () => _deck.nope(),
                ),
                const SizedBox(width: 18),
                _ActionButton(
                  icon: LucideIcons.star,
                  label: 'Super like',
                  color: Colors.white,
                  bg: AppColors.accent,
                  size: 50,
                  onTap: () => _deck.superLike(),
                ),
                const SizedBox(width: 18),
                _ActionButton(
                  icon: LucideIcons.heart,
                  label: 'Like',
                  color: Colors.white,
                  gradient: AppColors.brandGradient,
                  size: 68,
                  onTap: () => _deck.like(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline quick toggles. The full filter set (gender, age, city, …) lives in the
/// single filter sheet opened from the app-bar — this row is just fast access to
/// the two most-used switches, not another copy of the sheet.
class _QuickFilterRow extends ConsumerWidget {
  const _QuickFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(discoverFiltersProvider);
    final notifier = ref.read(discoverFiltersProvider.notifier);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _toggleChip(context, 'Verified', f.verifiedOnly,
              (_) => notifier.toggleVerified()),
          const SizedBox(width: 8),
          _toggleChip(context, 'Online now', f.onlineOnly,
              (_) => notifier.toggleOnline()),
          if (!f.isDefault) ...[
            const SizedBox(width: 8),
            Center(
              child: ActionChip(
                avatar: const Icon(LucideIcons.x, size: 15),
                label: const Text('Clear'),
                onPressed: notifier.reset,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toggleChip(BuildContext context, String label, bool selected,
      ValueChanged<bool> onSelected) {
    return Center(
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color:
              selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        onSelected: onSelected,
      ),
    );
  }
}

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.compass, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text('No one new nearby yet',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Widen your filters or check back soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => showDiscoverFilterSheet(context),
              icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
              label: const Text('Adjust filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  final VoidCallback onRefresh;
  const _CaughtUp({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.sparkles, size: 56, color: AppColors.accent),
            const SizedBox(height: 16),
            Text("You're all caught up",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('You have seen everyone for now. Come back soon for new faces.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(LucideIcons.rotateCw, size: 18),
              label: const Text('Start over'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? bg;
  final Gradient? gradient;
  final double size;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.bg,
    this.gradient,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Guarantee at least a 48dp hit target even when the visual circle is
    // smaller (rewind/super-like), per Material/Apple touch guidelines.
    final hit = size < 48 ? 48.0 : size;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: size * 0.42),
            ),
          ),
        ),
      ),
    );
  }
}
