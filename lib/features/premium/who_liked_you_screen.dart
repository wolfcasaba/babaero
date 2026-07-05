import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../matches/data/matches_provider.dart';
import '../profile/profile_detail_screen.dart';

/// The members who liked the current user. Free during launch (later this is a
/// Gold perk — the blur/gate reads is_gold).
class WhoLikedYouScreen extends ConsumerWidget {
  const WhoLikedYouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likersAsync = ref.watch(whoLikedMeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Likes you')),
      body: likersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (likers) {
          if (likers.isEmpty) return const _NoLikes();
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _FreeBanner()),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _LikerCard(profile: likers[i]),
                    childCount: likers.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FreeBanner extends StatelessWidget {
  const _FreeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Free during launch 🎉 See everyone who likes you.',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LikerCard extends StatelessWidget {
  final Profile profile;
  const _LikerCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(profile: profile))),
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
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.scrim],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${profile.name}, ${profile.age}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                  if (profile.verified) ...[
                    const SizedBox(width: 4),
                    const VerifiedBadge(size: 14),
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

class _NoLikes extends StatelessWidget {
  const _NoLikes();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.heart, size: 52, color: cs.outline),
            const SizedBox(height: 14),
            Text('No likes yet',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Keep an eye here — new admirers show up as they like you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}
