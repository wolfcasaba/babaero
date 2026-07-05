import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/brand_widgets.dart';
import 'data/stories_provider.dart';

/// Preview a picked photo, add an optional caption, and share it to your story.
class AddStoryScreen extends ConsumerStatefulWidget {
  final Uint8List bytes;
  final String ext;
  const AddStoryScreen({super.key, required this.bytes, required this.ext});

  @override
  ConsumerState<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends ConsumerState<AddStoryScreen> {
  final _caption = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(storyRepositoryProvider);
      final url = await repo.uploadStoryImage(widget.bytes, ext: widget.ext);
      if (url != null) {
        await repo.addStory(
          imageUrl: url,
          caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        );
        ref.invalidate(storiesProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared to your story 🎉')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share. Try again.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your story')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black,
              ),
              child: Image.memory(widget.bytes, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _caption,
              maxLength: 140,
              decoration: const InputDecoration(hintText: 'Add a caption…'),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GradientButton(
                label: _busy ? 'Sharing…' : 'Share to story',
                onPressed: _busy ? null : _share,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
