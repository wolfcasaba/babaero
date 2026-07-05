import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// Static help & support: a short FAQ + how to get in touch and stay safe.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How does translation work?',
      'Type in your language and we translate your message for your match, '
          'shown inline under each chat bubble. Toggle it in Translation settings.'
    ),
    (
      'How do I get verified?',
      'Open your profile → Get verified, then submit a photo or video. Verified '
          'members earn more trust and matches.'
    ),
    (
      'How do I make a group?',
      'Go to Messages → the group icon (top right), name the group and pick '
          'members from the people you\'ve matched with.'
    ),
    (
      'How do I block or report someone?',
      'Open their profile → the flag icon (top right) to report or block. '
          'Blocked members disappear from your Discover deck.'
    ),
    (
      'Is my information safe?',
      'We only show what you add to your profile. Never share financial details '
          'or send money to someone you met here.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.shieldCheck,
                    color: AppColors.verified, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stay safe: keep chats on Babaero and never send money to '
                    'someone you haven\'t met.',
                    style: GoogleFonts.inter(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('FAQ',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final f in _faqs)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ExpansionTile(
                shape: const Border(),
                title: Text(f.$1,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(f.$2, style: const TextStyle(height: 1.4))],
              ),
            ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(LucideIcons.mail, color: AppColors.primary),
            title: const Text('Contact support'),
            subtitle: const Text('support@babaero.app'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email us at support@babaero.app')),
            ),
          ),
        ],
      ),
    );
  }
}
