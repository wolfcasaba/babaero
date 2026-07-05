import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../discover/data/profile_models.dart';
import '../../profile/data/profile_provider.dart';
import '../add_story_screen.dart';
import '../data/stories_models.dart';
import '../data/stories_provider.dart';
import '../story_viewer_screen.dart';

/// The horizontal story bar shown atop the Feed: "Your story" + others' rings.
class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(storiesProvider).asData?.value ?? const <StoryGroup>[];
    final me = ref.watch(myProfileProvider).asData?.value;

    StoryGroup? myGroup;
    final others = <StoryGroup>[];
    for (final g in groups) {
      if (g.isMine && myGroup == null) {
        myGroup = g;
      } else if (!g.isMine) {
        others.add(g);
      }
    }

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _YourStory(
            me: me,
            hasStory: myGroup != null,
            hasUnseen: myGroup?.hasUnseen ?? false,
            onAdd: () => _pickAndAdd(context, ref),
            onView: myGroup == null
                ? null
                : () => _open(context, groups, groups.indexOf(myGroup!)),
          ),
          for (final g in others)
            _StoryRing(
              group: g,
              onTap: () => _open(context, groups, groups.indexOf(g)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndAdd(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 88);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddStoryScreen(bytes: bytes, ext: ext == 'png' ? 'png' : 'jpg'),
    ));
  }

  void _open(BuildContext context, List<StoryGroup> groups, int start) {
    if (start < 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StoryViewerScreen(groups: groups, startGroup: start),
    ));
  }
}

class _YourStory extends StatelessWidget {
  final Profile? me;
  final bool hasStory;
  final bool hasUnseen;
  final VoidCallback onAdd;
  final VoidCallback? onView;
  const _YourStory({
    required this.me,
    required this.hasStory,
    required this.hasUnseen,
    required this.onAdd,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return _StoryTile(
      label: 'Your story',
      ring: hasStory && hasUnseen,
      onTap: hasStory ? onView! : onAdd,
      avatar: Stack(
        children: [
          ProfileAvatar(
            photoUrl: me?.photoUrl,
            initial: me?.initial ?? '?',
            colorA: AppColors.primary,
            colorB: AppColors.secondary,
            size: 62,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: const CircleAvatar(
                  radius: 9,
                  backgroundColor: AppColors.primary,
                  child: Icon(LucideIcons.plus, size: 12, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryRing extends StatelessWidget {
  final StoryGroup group;
  final VoidCallback onTap;
  const _StoryRing({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _StoryTile(
      label: group.author.name,
      ring: group.hasUnseen,
      onTap: onTap,
      avatar: ProfileAvatar(
        photoUrl: group.author.photoUrl,
        initial: group.author.initial,
        colorA: group.author.colorA,
        colorB: group.author.colorB,
        size: 62,
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  final String label;
  final bool ring;
  final Widget avatar;
  final VoidCallback onTap;
  const _StoryTile({
    required this.label,
    required this.ring,
    required this.avatar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        margin: const EdgeInsets.only(right: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ring ? AppColors.brandGradient : null,
                color: ring ? null : cs.outlineVariant,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                ),
                child: avatar,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
