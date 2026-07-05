import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'data/app_settings.dart';

/// Translation preferences. The auto-translate toggle is honored by the chat
/// and group send flows immediately.
class TranslationSettingsScreen extends ConsumerWidget {
  const TranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Translation')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings.\n$e')),
        data: (s) => ListView(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.languages, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tagalog ↔ English',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        Text('Messages are translated inline as you chat.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              activeThumbColor: AppColors.primary,
              secondary: const Icon(LucideIcons.wandSparkles),
              title: const Text('Auto-translate messages'),
              subtitle: const Text(
                  'Translate your outgoing messages to the other language'),
              value: s.autoTranslate,
              onChanged: n.setAutoTranslate,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                s.autoTranslate
                    ? 'Your messages are sent in your language with a translation '
                        'shown underneath for your match.'
                    : 'Auto-translate is off — messages are sent exactly as typed.',
                style: TextStyle(color: cs.outline, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
