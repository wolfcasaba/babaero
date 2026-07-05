import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/profile_models.dart';
import '../matches/data/matches_provider.dart';
import 'data/group_provider.dart';
import 'group_thread_screen.dart';

/// Create a group from the people you've matched with: name it, pick members,
/// tap Create → the group is made and you're dropped into its thread.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _title = TextEditingController();
  final _selected = <String>{};
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create(List<Profile> matches) async {
    if (_selected.isEmpty || _creating) return;
    setState(() => _creating = true);
    final title = _title.text.trim().isEmpty
        ? _defaultTitle(matches)
        : _title.text.trim();
    try {
      final id = await ref
          .read(groupRepositoryProvider)
          .createGroup(title, _selected.toList());
      ref.invalidate(groupsProvider);
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the group.')),
        );
        setState(() => _creating = false);
        return;
      }
      // Replace this screen with the new group's thread.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupThreadScreen(groupId: id, title: title),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the group.')),
      );
      setState(() => _creating = false);
    }
  }

  /// A friendly default name from the first couple of selected members.
  String _defaultTitle(List<Profile> matches) {
    final names = [
      for (final p in matches)
        if (_selected.contains(p.id)) p.name,
    ];
    if (names.isEmpty) return 'New group';
    if (names.length <= 2) return names.join(' & ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final matches =
        ref.watch(matchesProvider).asData?.value ?? const <Profile>[];

    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Group name (optional)',
                prefixIcon: const Icon(LucideIcons.usersRound),
                fillColor: cs.surfaceContainerHighest,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selected.isEmpty
                    ? 'Add members from your matches'
                    : '${_selected.length} selected',
                style: TextStyle(color: cs.outline, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? _NoMatches()
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (_, i) {
                      final p = matches[i];
                      final on = _selected.contains(p.id);
                      return CheckboxListTile(
                        value: on,
                        activeColor: AppColors.primary,
                        controlAffinity: ListTileControlAffinity.trailing,
                        onChanged: (_) => setState(() {
                          on ? _selected.remove(p.id) : _selected.add(p.id);
                        }),
                        secondary: ProfileAvatar(
                          photoUrl: p.photoUrl,
                          initial: p.initial,
                          colorA: p.colorA,
                          colorB: p.colorB,
                          size: 46,
                        ),
                        title: Row(
                          children: [
                            Text(p.name,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                            if (p.verified) ...[
                              const SizedBox(width: 5),
                              const VerifiedBadge(size: 14),
                            ],
                          ],
                        ),
                        subtitle: Text(p.city,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
          ),
          if (matches.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GradientButton(
                  label: _creating ? 'Creating…' : 'Create group',
                  icon: LucideIcons.check,
                  onPressed: _selected.isEmpty || _creating
                      ? null
                      : () => _create(matches),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.usersRound, size: 52, color: cs.outline),
            const SizedBox(height: 14),
            Text('No matches yet',
                style: GoogleFonts.poppins(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Match with people first, then group them up here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}
