import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/discover_provider.dart';
import '../profile/data/profile_provider.dart';
import 'who_liked_you_screen.dart';

/// Babaero Gold — the premium showcase. FREE during launch: every perk is live
/// for everyone; the paywall is a waitlist for now. When membership launches,
/// gate the perks on `profile.isGold` and swap the CTA for checkout.
class BabaeroGoldScreen extends ConsumerStatefulWidget {
  const BabaeroGoldScreen({super.key});

  @override
  ConsumerState<BabaeroGoldScreen> createState() => _BabaeroGoldScreenState();
}

class _BabaeroGoldScreenState extends ConsumerState<BabaeroGoldScreen> {
  bool _boosting = false;

  static const _perks = [
    (LucideIcons.heart, 'See who likes you', 'Skip the guessing — view every admirer.'),
    (LucideIcons.infinity, 'Unlimited likes', 'Like as many people as you want.'),
    (LucideIcons.zap, 'Monthly boosts', 'Jump to the top of the deck and get seen.'),
    (LucideIcons.plane, 'Passport', 'Browse and match in any city.'),
    (LucideIcons.slidersHorizontal, 'Advanced filters', 'Filter by what matters to you.'),
    (LucideIcons.checkCheck, 'Read receipts', 'Know when your messages are read.'),
  ];

  Future<void> _boost() async {
    if (_boosting) return;
    setState(() => _boosting = true);
    try {
      await ref.read(profileRepositoryProvider).boost();
      ref.invalidate(discoverProfilesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You\'re boosted! You\'ll be seen more for a while ⚡')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not boost. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _boosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Babaero Gold')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.nightGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.crown, color: AppColors.accent, size: 44),
                const SizedBox(height: 12),
                Text('Babaero Gold',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Everything, unlocked.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text('FREE DURING LAUNCH',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF3A2A00),
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final p in _perks)
            _PerkRow(icon: p.$1, title: p.$2, subtitle: p.$3),
          const SizedBox(height: 16),
          GradientButton(
            label: _boosting ? 'Boosting…' : 'Boost me now',
            icon: LucideIcons.zap,
            onPressed: _boosting ? null : _boost,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const WhoLikedYouScreen())),
            child: const Text('See who likes you'),
          ),
          const SizedBox(height: 16),
          Text(
            'Gold is free while we grow. When memberships launch, early '
            'members get the best price.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outline, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PerkRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
