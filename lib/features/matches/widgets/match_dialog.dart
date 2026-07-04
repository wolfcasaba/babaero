import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../chat/chat_thread_screen.dart';
import '../../discover/data/profile_models.dart';

/// Full-screen celebratory "It's a Match!" overlay.
Future<void> showMatchDialog(BuildContext context, Profile other) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'match',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => _MatchOverlay(other: other),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

class _MatchOverlay extends StatelessWidget {
  final Profile other;
  const _MatchOverlay({required this.other});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          gradient: AppColors.nightGradient,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [Colors.white, Color(0xFFFFD9A8)])
                      .createShader(b),
              child: Text(
                'It\'s a Match!',
                style: GoogleFonts.poppins(
                    fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You and ${other.name} liked each other',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GradientAvatar(
                  initial: 'You',
                  colorA: AppColors.primary,
                  colorB: AppColors.secondary,
                  size: 84,
                ),
                Transform.translate(
                  offset: const Offset(-12, 0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.heart,
                        color: AppColors.primary, size: 22),
                  ),
                ),
                ProfileAvatar(
                  photoUrl: other.photoUrl,
                  initial: other.initial,
                  colorA: other.colorA,
                  colorB: other.colorB,
                  size: 84,
                ),
              ],
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Send a message',
              icon: LucideIcons.messageCircle,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(profile: other),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep exploring',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
