import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/widgets/brand_widgets.dart';
import '../auth/data/auth_provider.dart';
import '../discover/data/discover_provider.dart';
import '../premium/gold_screen.dart';
import '../safety/blocked_users_screen.dart';
import '../settings/help_screen.dart';
import '../settings/notifications_screen.dart';
import '../settings/translation_settings_screen.dart';
import 'data/profile_provider.dart';
import 'edit_profile_screen.dart';
import 'onboarding_setup_screen.dart';
import 'photo_gallery_screen.dart';
import 'verification_screen.dart';

/// Type-DELETE confirmation → permanently delete the account via the edge
/// function. On success the auth session is cleared and the gate returns to the
/// welcome screen.
Future<void> _confirmAndDeleteAccount(
    BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This permanently deletes your profile, matches, messages and '
                'photos. This cannot be undone.\n\nType DELETE to confirm.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'DELETE'),
              onChanged: (_) => setLocal(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: controller.text.trim().toUpperCase() == 'DELETE'
                ? () => Navigator.pop(ctx, true)
                : null,
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (confirmed != true) return;
  try {
    await ref.read(authRepositoryProvider).deleteAccount();
    // signOut inside deleteAccount flips the auth gate back to welcome.
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not delete the account. Try again.')),
      );
    }
  }
}

Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
  final picked = await ImagePicker()
      .pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
  if (picked == null) return;
  final bytes = await picked.readAsBytes();
  final ext = picked.name.split('.').last.toLowerCase();
  try {
    await ref.read(profileRepositoryProvider).uploadAvatar(
          bytes,
          ext: ext == 'png' ? 'png' : 'jpg',
        );
    ref.invalidate(myProfileProvider);
    ref.invalidate(discoverProfilesProvider);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo. Try again.')),
      );
    }
  }
}

/// The signed-in member's own profile + settings entry points.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final me = ref.watch(myProfileProvider).asData?.value;
    final name = me?.name.isNotEmpty == true ? me!.name : 'Your profile';
    final title = me?.age != null && me!.age > 0 ? '$name, ${me.age}' : name;
    final location = [me?.city, me?.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    final verified = me?.verified ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    ProfileAvatar(
                      photoUrl: me?.photoUrl,
                      initial: me?.initial ?? '?',
                      colorA: AppColors.primary,
                      colorB: AppColors.secondary,
                      size: 96,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _pickAndUploadAvatar(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.camera, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(size: 20),
                    ],
                  ],
                ),
                if (location.isNotEmpty)
                  Text(location,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BabaeroGoldScreen()),
            ),
            child: _PremiumCard(),
          ),
          const SizedBox(height: 20),
          _VerificationRow(verified: verified),
          const SizedBox(height: 12),
          _SettingsGroup(
            items: const [
              (LucideIcons.userPen, 'Edit profile'),
              (LucideIcons.image, 'My photos'),
              (LucideIcons.languages, 'Translation settings'),
            ],
            onTap: (label) {
              switch (label) {
                case 'Edit profile':
                  if (me != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: me)));
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const OnboardingSetupScreen()));
                  }
                case 'My photos':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PhotoGalleryScreen()));
                case 'Translation settings':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TranslationSettingsScreen()));
                default:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon.')),
                  );
              }
            },
          ),
          const SizedBox(height: 12),
          _SettingsGroup(
            items: const [
              (LucideIcons.shield, 'Safety & privacy'),
              (LucideIcons.bell, 'Notifications'),
              (LucideIcons.circleHelp, 'Help & support'),
              (LucideIcons.logOut, 'Log out'),
              (LucideIcons.trash2, 'Delete account'),
            ],
            onTap: (label) async {
              switch (label) {
                case 'Log out':
                  await ref.read(authRepositoryProvider).signOut();
                case 'Delete account':
                  await _confirmAndDeleteAccount(context, ref);
                case 'Safety & privacy':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen()));
                case 'Notifications':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()));
                case 'Help & support':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const HelpScreen()));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.nightGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.crown, color: AppColors.accent, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Babaero Gold',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                Text('See who likes you · unlimited translation · boosts',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  final bool verified;
  const _VerificationRow({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.verified : AppColors.secondary;
    return InkWell(
      onTap: verified
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VerificationScreen()),
              ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            verified
                ? const VerifiedBadge(size: 24)
                : Icon(LucideIcons.badgeCheck, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                verified
                    ? 'You\'re verified — members trust verified profiles more.'
                    : 'Get verified to earn trust and unlock more matches.',
                style: GoogleFonts.inter(fontSize: 13.5),
              ),
            ),
            if (!verified) const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<(IconData, String)> items;
  final void Function(String label)? onTap;
  const _SettingsGroup({required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].$1,
                  color: items[i].$2 == 'Log out'
                      ? AppColors.danger
                      : Theme.of(context).colorScheme.onSurface),
              title: Text(items[i].$2),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => onTap?.call(items[i].$2),
            ),
            if (i < items.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}
