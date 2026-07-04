import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../chat/chat_thread_screen.dart';
import '../discover/data/profile_models.dart';

/// Full profile view — opened from Discover or Matches.
class ProfileDetailScreen extends StatelessWidget {
  final Profile profile;
  const ProfileDetailScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: cs.surface,
            leading: const _CircleIconButton(icon: LucideIcons.arrowLeft),
            actions: const [
              _CircleIconButton(icon: LucideIcons.flag),
              SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: profile.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    )
                  else
                    Center(
                      child: Text(
                        profile.initial,
                        style: GoogleFonts.poppins(
                          fontSize: 150,
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
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${profile.name}, ${profile.age}',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (profile.verified) const VerifiedBadge(size: 22),
                      const Spacer(),
                      if (profile.online) const OnlineDot(size: 12),
                      if (profile.online)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('Online',
                              style: TextStyle(color: AppColors.online)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text('${profile.city}, ${profile.country} · '
                          '${profile.distanceKm} km'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (profile.verified) _VerificationCard(),
                  const SizedBox(height: 20),
                  _sectionTitle('About'),
                  const SizedBox(height: 8),
                  Text(
                    profile.bio,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Languages'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.languages,
                          size: 18, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(profile.languages)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Interests'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.interests
                        .map((t) => Chip(label: Text(t)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        color: cs.surface,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _CircleAction(
                icon: LucideIcons.x,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: 'Message',
                  icon: LucideIcons.messageCircle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatThreadScreen(profile: profile),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CircleAction(
                icon: LucideIcons.heart,
                gradient: AppColors.brandGradient,
                iconColor: Colors.white,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
      );
}

class _VerificationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.verified.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.verified.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const VerifiedBadge(size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verified member',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const Text('Photo & video confirmed',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  const _CircleIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: CircleAvatar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Gradient? gradient;
  final Color? iconColor;
  final VoidCallback onTap;
  const _CircleAction({
    required this.icon,
    this.gradient,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? cs.surfaceContainerHighest : null,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? cs.onSurface),
      ),
    );
  }
}
