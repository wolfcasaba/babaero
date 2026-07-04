import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../matches/data/matches_provider.dart';
import '../matches/widgets/match_dialog.dart';
import '../profile/profile_detail_screen.dart';
import 'data/discover_provider.dart';
import 'data/profile_models.dart';

/// The main browse surface — one hero profile card at a time with
/// pass / like / super-like actions and a filter row.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  int _current = 0;
  bool _acting = false;

  void _next(int total) {
    if (total == 0) return;
    setState(() => _current = (_current + 1) % total);
  }

  Future<void> _like(Profile p, int total, {bool superLike = false}) async {
    if (_acting) return;
    _acting = true;
    try {
      final matched =
          await ref.read(matchesRepositoryProvider).like(p.id, superLike: superLike);
      ref.invalidate(matchesProvider);
      ref.invalidate(likesYouCountProvider);
      if (matched && mounted) {
        await showMatchDialog(context, p);
      }
    } catch (_) {
      // silent — optimistic advance below
    } finally {
      _acting = false;
      if (mounted) _next(total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profilesAsync = ref.watch(discoverProfilesProvider);
    final profiles = profilesAsync.asData?.value ?? const <Profile>[];
    final count = profiles.length;
    final current = count > 0 ? profiles[_current % count] : null;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const BrandWordmark(fontSize: 24),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.slidersHorizontal),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _FilterRow(),
          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load profiles.\n$e',
                  textAlign: TextAlign.center)),
              data: (profiles) {
                if (profiles.isEmpty) {
                  return const _EmptyDiscover();
                }
                final p = profiles[_current % profiles.length];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _ProfileCard(
                    profile: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileDetailScreen(profile: p),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: LucideIcons.x,
                  color: cs.onSurface,
                  bg: cs.surface,
                  size: 60,
                  onTap: () => _next(count),
                ),
                const SizedBox(width: 18),
                _ActionButton(
                  icon: LucideIcons.star,
                  color: Colors.white,
                  bg: AppColors.accent,
                  size: 50,
                  onTap: current == null
                      ? null
                      : () => _like(current, count, superLike: true),
                ),
                const SizedBox(width: 18),
                _ActionButton(
                  icon: LucideIcons.heart,
                  color: Colors.white,
                  gradient: AppColors.brandGradient,
                  size: 68,
                  onTap: current == null ? null : () => _like(current, count),
                ),
              ],
            ),
          ),
        ],
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
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  static const _filters = ['Nearby', 'Verified', 'Online now', '18-30', 'Cebu'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == 1; // "Verified" pre-selected for the design
          return Center(
            child: FilterChip(
              label: Text(_filters[i]),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              onSelected: (_) {},
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;
  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient base (fallback when there's no photo).
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [profile.colorA, profile.colorB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            if (profile.hasPhoto)
              CachedNetworkImage(
                imageUrl: profile.photoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              )
            else
              Align(
                alignment: Alignment.center,
                child: Text(
                  profile.initial,
                  style: GoogleFonts.poppins(
                    fontSize: 120,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            // Bottom scrim for legibility.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            // Top-right status pills.
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  if (profile.online) _pill(LucideIcons.circle, 'Online'),
                ],
              ),
            ),
            // Bottom info.
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${profile.name}, ${profile.age}',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (profile.verified) const VerifiedBadge(size: 22),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.city} · ${profile.distanceKm} km away',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.interests
                        .take(3)
                        .map((t) => _interestChip(t))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circle,
              size: 9, color: AppColors.online, fill: 1),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _interestChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? bg;
  final Gradient? gradient;
  final double size;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.color,
    this.bg,
    this.gradient,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
