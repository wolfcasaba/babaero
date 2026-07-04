import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import 'data/verification_repository.dart';

final _verificationRepoProvider =
    Provider<VerificationRepository>((_) => VerificationRepository());

final verificationStatusProvider = FutureProvider<String?>(
    (ref) => ref.watch(_verificationRepoProvider).latestStatus());

/// Explains verification and lets the member submit a photo/video request.
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(verificationStatusProvider).asData?.value;
    final pending = status == 'pending';
    return Scaffold(
      appBar: AppBar(title: const Text('Get verified')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.nightGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.shieldCheck,
                    color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  'The green badge builds trust',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Verified members get up to 3× more replies. It only takes '
                  'a moment and your selfie is never shown publicly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (pending)
            _StatusCard(
              icon: LucideIcons.clock,
              color: AppColors.accent,
              title: 'Verification pending',
              body: 'We\'re reviewing your submission — this usually takes a '
                  'few minutes.',
            )
          else if (status == 'approved')
            _StatusCard(
              icon: LucideIcons.badgeCheck,
              color: AppColors.verified,
              title: 'You\'re verified 🎉',
              body: 'Your profile now shows the green badge.',
            )
          else ...[
            _Step(
                n: 1,
                text: 'Take a quick selfie matching a prompted pose.'),
            _Step(n: 2, text: 'Our team compares it to your profile photos.'),
            _Step(n: 3, text: 'Get the badge — usually within minutes.'),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Start photo verification',
              icon: LucideIcons.camera,
              onPressed: () => _submit(context, ref, 'photo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(LucideIcons.video),
              label: const Text('Start video verification'),
              onPressed: () => _submit(context, ref, 'video'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(
      BuildContext context, WidgetRef ref, String type) async {
    await ref.read(_verificationRepoProvider).submit(type);
    ref.invalidate(verificationStatusProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted — pending review.')),
      );
    }
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text('$n',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
