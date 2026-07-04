import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/supabase/backend_settings_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../auth/auth_screen.dart';

/// First-run hero. Night-luxe gradient, wordmark, value props, CTA.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: BackendSettingsButton(),
                ),
                const Spacer(flex: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.heart,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Babaero',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Where the world\nmeets the Philippines.',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Verified profiles. Real conversations. '
                  'Built-in translation so language is never the barrier.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 24),
                const _ValueProp(
                  icon: LucideIcons.badgeCheck,
                  text: 'Photo & video verified members',
                ),
                const _ValueProp(
                  icon: LucideIcons.languages,
                  text: 'Instant English ↔ Tagalog translation',
                ),
                const _ValueProp(
                  icon: LucideIcons.shieldCheck,
                  text: 'Safety-first, report & block anytime',
                ),
                const Spacer(flex: 3),
                GradientButton(
                  label: 'Create account',
                  icon: LucideIcons.sparkles,
                  onPressed: () => _openAuth(context, signUp: true),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _openAuth(context, signUp: false),
                    child: Text(
                      'I already have an account',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'By continuing you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAuth(BuildContext context, {required bool signUp}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AuthScreen(startInSignUp: signUp)),
    );
  }
}

class _ValueProp extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValueProp({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
