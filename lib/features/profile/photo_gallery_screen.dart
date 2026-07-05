import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../discover/data/discover_provider.dart';
import 'data/profile_provider.dart';

/// Manage the member's photo gallery: add, delete, and pick the primary
/// (avatar). The first photo in the array is the avatar shown everywhere.
class PhotoGalleryScreen extends ConsumerStatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
      ref.invalidate(myProfileProvider);
      ref.invalidate(discoverProfilesProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    await _run(() => ref.read(profileRepositoryProvider).addPhoto(
          bytes,
          ext: ext == 'png' ? 'png' : 'jpg',
        ));
  }

  @override
  Widget build(BuildContext context) {
    final photos =
        ref.watch(myProfileProvider).asData?.value?.photos ?? const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('My photos')),
      body: Stack(
        children: [
          GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (var i = 0; i < photos.length; i++)
                _PhotoTile(
                  url: photos[i],
                  isPrimary: i == 0,
                  onSetPrimary: i == 0
                      ? null
                      : () => _run(() => ref
                          .read(profileRepositoryProvider)
                          .setPrimaryPhoto(photos[i])),
                  onDelete: () => _confirmDelete(photos[i]),
                ),
              _AddTile(onTap: _add),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This removes the photo from your profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => ref.read(profileRepositoryProvider).removePhoto(url));
    }
  }
}

class _PhotoTile extends StatelessWidget {
  final String url;
  final bool isPrimary;
  final VoidCallback? onSetPrimary;
  final VoidCallback onDelete;
  const _PhotoTile({
    required this.url,
    required this.isPrimary,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const ColoredBox(
              color: Colors.black26,
              child: Icon(LucideIcons.imageOff, color: Colors.white54),
            ),
          ),
          if (isPrimary)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Main',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: _MiniButton(
              icon: LucideIcons.trash2,
              onTap: onDelete,
            ),
          ),
          if (onSetPrimary != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: _MiniButton(
                icon: LucideIcons.star,
                tooltip: 'Set as main',
                onTap: onSetPrimary!,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  const _MiniButton({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Tooltip(
              message: tooltip ?? '',
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DottedborderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, color: cs.outline),
            const SizedBox(height: 4),
            Text('Add', style: TextStyle(color: cs.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// A simple dashed-look add tile (a subtle bordered container, no extra deps).
class DottedborderBox extends StatelessWidget {
  final Widget child;
  const DottedborderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}
