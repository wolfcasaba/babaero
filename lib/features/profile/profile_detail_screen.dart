import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../chat/chat_thread_screen.dart';
import '../discover/data/compatibility.dart';
import '../discover/data/discover_provider.dart';
import '../discover/data/profile_models.dart';
import '../matches/data/matches_provider.dart';
import '../matches/widgets/match_dialog.dart';
import '../safety/data/safety_provider.dart';
import 'data/profile_provider.dart';

/// Full profile view — opened from Discover or Matches.
class ProfileDetailScreen extends ConsumerStatefulWidget {
  final Profile profile;
  const ProfileDetailScreen({super.key, required this.profile});

  @override
  ConsumerState<ProfileDetailScreen> createState() =>
      _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<ProfileDetailScreen> {
  bool _acting = false;

  Profile get profile => widget.profile;

  Future<void> _like() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final matched = await ref.read(matchesRepositoryProvider).like(profile.id);
      ref.invalidate(matchesProvider);
      ref.invalidate(likesYouCountProvider);
      if (!mounted) return;
      if (matched) {
        await showMatchDialog(context, profile);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You liked ${profile.name} 💕')),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send like. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openSafetySheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.flag, color: AppColors.secondary),
              title: Text('Report ${profile.name}'),
              subtitle: const Text('Tell us what\'s wrong'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.ban, color: AppColors.danger),
              title: Text('Block ${profile.name}'),
              subtitle: const Text('They won\'t appear in Discover'),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'report') await _report();
    if (action == 'block') await _block();
  }

  Future<void> _report() async {
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
      await ref.read(safetyRepositoryProvider).report(profile.id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks — we\'ll review this report.')),
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

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${profile.name}?'),
        content: const Text(
            'They won\'t appear in your Discover deck. You can unblock later '
            'from Safety & privacy.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Block', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(safetyRepositoryProvider).block(profile.id);
      ref.invalidate(blockedIdsProvider);
      ref.invalidate(discoverProfilesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${profile.name} blocked.')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = ref.watch(myProfileProvider).asData?.value;
    final compat = compatibility(me, profile);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: cs.surface,
            leading: _CircleIconButton(
              icon: LucideIcons.arrowLeft,
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
            ),
            actions: [
              _CircleIconButton(
                icon: LucideIcons.flag,
                tooltip: 'Report or block',
                onPressed: _openSafetySheet,
              ),
              const SizedBox(width: 12),
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
                        colors: [Colors.transparent, AppColors.scrim],
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
                      Flexible(
                        child: Text(
                          '${profile.name}, ${profile.age}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
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
                      Expanded(
                        // Append distance only when known (avoid a phantom 0 km).
                        child: Text(profile.distanceKm > 0
                            ? '${profile.city}, ${profile.country} · ${profile.distanceKm} km'
                            : '${profile.city}, ${profile.country}'),
                      ),
                    ],
                  ),
                  if (compat != null && compat.hasSignal) ...[
                    const SizedBox(height: 16),
                    _CompatCard(compat: compat, name: profile.name),
                  ],
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
                  if (profile.prompts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('More about ${profile.name}'),
                    const SizedBox(height: 10),
                    for (final pr in profile.prompts) _PromptDisplay(prompt: pr),
                  ],
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
                onTap: _acting ? null : _like,
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

class _CompatCard extends StatelessWidget {
  final Compat compat;
  final String name;
  const _CompatCard({required this.compat, required this.name});

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      if (compat.sharedInterests.isNotEmpty)
        'you both like ${compat.sharedInterests.take(3).join(', ')}',
      if (compat.sharedLanguage) 'share a language',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${compat.percent}% match',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                if (bits.isNotEmpty)
                  Text(
                    '${_cap(bits.first)}${bits.length > 1 ? ' · ${bits[1]}' : ''}.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PromptDisplay extends StatelessWidget {
  final ProfilePrompt prompt;
  const _PromptDisplay({required this.prompt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt.question,
              style: TextStyle(fontSize: 13, color: cs.outline)),
          const SizedBox(height: 6),
          Text(prompt.answer,
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: CircleAvatar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Gradient? gradient;
  final Color? iconColor;
  final VoidCallback? onTap;
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
