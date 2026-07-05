import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'data/app_settings.dart';

/// Notification preferences. Stored on-device; honored by the push layer once
/// push notifications ship.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings.\n$e')),
        data: (s) => ListView(
          children: [
            const _InfoBanner(
              icon: LucideIcons.bell,
              text:
                  'Choose what you\'re notified about. Push delivery arrives in '
                  'a future update — your choices are saved now.',
            ),
            SwitchListTile(
              activeThumbColor: AppColors.primary,
              secondary: const Icon(LucideIcons.heart),
              title: const Text('New matches'),
              subtitle: const Text('When you and someone like each other'),
              value: s.notifyMatches,
              onChanged: n.setNotifyMatches,
            ),
            SwitchListTile(
              activeThumbColor: AppColors.primary,
              secondary: const Icon(LucideIcons.messageCircle),
              title: const Text('Messages'),
              subtitle: const Text('New chat and group messages'),
              value: s.notifyMessages,
              onChanged: n.setNotifyMessages,
            ),
            SwitchListTile(
              activeThumbColor: AppColors.primary,
              secondary: const Icon(LucideIcons.star),
              title: const Text('Likes'),
              subtitle: const Text('When someone likes your profile'),
              value: s.notifyLikes,
              onChanged: n.setNotifyLikes,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
