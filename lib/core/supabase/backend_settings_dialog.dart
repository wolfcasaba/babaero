import 'package:flutter/material.dart';

import 'backend_prefs.dart';
import 'supabase_config.dart';

/// Lets the user point the app at a local Supabase reached through a tunnel
/// (URL changes between sessions) without rebuilding. Applied on next launch.
Future<void> showBackendSettings(BuildContext context) async {
  final urlCtrl = TextEditingController(text: SupabaseConfig.effectiveUrl);
  final secretCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Backend connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Paste the tunnel URL for the local Supabase (e.g. '
            'https://xxxx.trycloudflare.com). Leave the secret empty unless '
            'the tunnel is header-gated.',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: urlCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Backend URL'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: secretCtrl,
            autocorrect: false,
            decoration:
                const InputDecoration(hintText: 'Access secret (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await BackendPrefs.clear();
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await BackendPrefs.save(
              url: urlCtrl.text,
              secret: secretCtrl.text,
            );
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (saved == true && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saved'),
        content: const Text('Close and reopen the app to connect to the new '
            'backend.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  urlCtrl.dispose();
  secretCtrl.dispose();
}

/// A subtle gear button that opens [showBackendSettings]. White-on-dark for
/// the welcome hero.
class BackendSettingsButton extends StatelessWidget {
  final Color color;
  const BackendSettingsButton({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Backend connection',
      icon: Icon(Icons.dns_outlined, color: color.withValues(alpha: 0.8)),
      onPressed: () => showBackendSettings(context),
    );
  }
}
