import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'data/timeline_provider.dart';

/// Compose a new timeline post: text and/or one image. Pops `true` on success
/// so the caller can refresh the feed.
class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key});

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  final _text = TextEditingController();
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canPost =>
      !_posting && (_text.text.trim().isNotEmpty || _imageBytes != null);

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageExt = ext == 'png' ? 'png' : 'jpg';
    });
  }

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() => _posting = true);
    final repo = ref.read(timelineRepositoryProvider);
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await repo.uploadPostImage(_imageBytes!, ext: _imageExt);
      }
      await repo.createPost(content: _text.text.trim(), imageUrl: imageUrl);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create post'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton(
              onPressed: _canPost ? _post : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: cs.surfaceContainerHighest,
              ),
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
            maxLength: 1000,
            style: const TextStyle(fontSize: 16, height: 1.4),
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _imageBytes!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageBytes = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.x,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(LucideIcons.imagePlus, size: 18),
                label: Text(_imageBytes == null ? 'Add photo' : 'Change photo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(LucideIcons.languages,
                  size: 15, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Write in your own language — readers can translate your post '
                  'to Tagalog or English with one tap.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: cs.outline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
