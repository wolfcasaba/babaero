import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// The Babaero wordmark — gradient text. Use in headers / splash.
class BrandWordmark extends StatelessWidget {
  final double fontSize;
  const BrandWordmark({super.key, this.fontSize = 34});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
      child: Text(
        'Babaero',
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Full-width gradient CTA button.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small verified badge — a green rosette with a check.
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.verified,
        shape: BoxShape.circle,
      ),
      child: Icon(LucideIcons.check, size: size * 0.62, color: Colors.white),
    );
  }
}

/// Gradient placeholder avatar with an initial — stands in for a real photo.
class GradientAvatar extends StatelessWidget {
  final String initial;
  final Color colorA;
  final Color colorB;
  final double size;
  const GradientAvatar({
    super.key,
    required this.initial,
    required this.colorA,
    required this.colorB,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colorA, colorB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Circular avatar: shows the network photo when [photoUrl] is set, otherwise
/// the gradient placeholder with an initial.
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final Color colorA;
  final Color colorB;
  final double size;
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.initial,
    required this.colorA,
    required this.colorB,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = GradientAvatar(
      initial: initial,
      colorA: colorA,
      colorB: colorB,
      size: size,
    );
    if (photoUrl == null || photoUrl!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Small online dot.
class OnlineDot extends StatelessWidget {
  final double size;
  const OnlineDot({super.key, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.online,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
