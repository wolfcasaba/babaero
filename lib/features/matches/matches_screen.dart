import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../profile/profile_detail_screen.dart';
import 'data/matches_provider.dart';

/// People you matched with + who liked you (behind a premium teaser).
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final likesYou = ref.watch(likesYouCountProvider).asData?.value ?? 0;
    final matches = matchesAsync.asData?.value ?? const <Profile>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchesProvider);
          ref.invalidate(likesYouCountProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _LikesTeaser(count: likesYou),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'New matches',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (matchesAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (matches.isEmpty)
              const SliverToBoxAdapter(child: _NoMatches())
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.74,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _MatchCard(profile: matches[i]),
                    childCount: matches.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(LucideIcons.heartHandshake, size: 56, color: cs.outline),
          const SizedBox(height: 16),
          Text('No matches yet',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Like people in Discover — when they like you back, '
              'they show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline)),
        ],
      ),
    );
  }
}

class _LikesTeaser extends StatelessWidget {
  final int count;
  const _LikesTeaser({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.heart, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count people like you',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Upgrade to see who they are',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Colors.white),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Profile profile;
  const _MatchCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(profile: profile),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
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
              Center(
                child: Text(
                  profile.initial,
                  style: GoogleFonts.poppins(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB3000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${profile.name}, ${profile.age}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (profile.verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 15),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
