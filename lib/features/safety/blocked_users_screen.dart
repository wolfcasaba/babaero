import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/widgets/brand_widgets.dart';
import '../discover/data/discover_provider.dart';
import '../discover/data/profile_models.dart';
import 'data/safety_provider.dart';

/// Safety & privacy — the list of members you've blocked, with unblock.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedProfilesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & privacy')),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (list) {
          if (list.isEmpty) return const _NoBlocks();
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('Blocked members',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final p in list) _BlockedTile(profile: p),
            ],
          );
        },
      ),
    );
  }
}

class _BlockedTile extends ConsumerStatefulWidget {
  final Profile profile;
  const _BlockedTile({required this.profile});

  @override
  ConsumerState<_BlockedTile> createState() => _BlockedTileState();
}

class _BlockedTileState extends ConsumerState<_BlockedTile> {
  bool _busy = false;

  Future<void> _unblock() async {
    setState(() => _busy = true);
    try {
      await ref.read(safetyRepositoryProvider).unblock(widget.profile.id);
      ref.invalidate(blockedProfilesProvider);
      ref.invalidate(blockedIdsProvider);
      ref.invalidate(discoverProfilesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unblock. Try again.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ListTile(
      leading: ProfileAvatar(
        photoUrl: p.photoUrl,
        initial: p.initial,
        colorA: p.colorA,
        colorB: p.colorB,
        size: 46,
      ),
      title: Text(p.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      subtitle: Text(p.city),
      trailing: _busy
          ? const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : OutlinedButton(onPressed: _unblock, child: const Text('Unblock')),
    );
  }
}

class _NoBlocks extends StatelessWidget {
  const _NoBlocks();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shieldCheck, size: 52, color: cs.outline),
            const SizedBox(height: 14),
            Text('No blocked members',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('People you block from a profile appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}
