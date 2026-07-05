import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../discover/data/discover_provider.dart';
import '../discover/data/profile_models.dart';
import 'data/profile_provider.dart';

const _interestChoices = [
  'Travel', 'Foodie', 'Beach', 'Karaoke', 'Movies', 'Fitness', 'Cooking',
  'Faith', 'Family', 'Dogs', 'Cats', 'Photography', 'Books', 'Music',
  'Hiking', 'Business', 'Dancing', 'Gaming',
];

/// Collected right after sign-up — writes the member's babaero.profiles row.
class OnboardingSetupScreen extends ConsumerStatefulWidget {
  const OnboardingSetupScreen({super.key});

  @override
  ConsumerState<OnboardingSetupScreen> createState() =>
      _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState
    extends ConsumerState<OnboardingSetupScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _languages = TextEditingController();
  final _bio = TextEditingController();
  String _role = 'foreigner';
  String _gender = 'male';
  final Set<String> _interests = {};
  final List<ProfilePrompt> _prompts = [];
  bool _busy = false;
  String? _error;

  // Photo picked during onboarding — uploaded AFTER the profile row is created
  // (the photos write is an UPDATE, so the row must exist first).
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  @override
  void dispose() {
    for (final c in [_name, _age, _country, _city, _languages, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoExt = ext == 'png' ? 'png' : 'jpg';
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).upsert(
            name: _name.text.trim(),
            age: int.tryParse(_age.text.trim()),
            gender: _gender,
            role: _role,
            country: _country.text.trim(),
            city: _city.text.trim(),
            languages: _languages.text.trim(),
            bio: _bio.text.trim(),
            interests: _interests.toList(),
            prompts: _prompts,
          );
      // The profile row now exists — upload the chosen avatar into it.
      if (_photoBytes != null) {
        await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(_photoBytes!, ext: _photoExt);
      }
      ref.invalidate(myProfileProvider);
      ref.invalidate(discoverProfilesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Could not save your profile. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tell us about you',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Verified, complete profiles get far more matches.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 20),
            Center(child: _PhotoPicker(bytes: _photoBytes, onTap: _pickPhoto)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _photoBytes == null
                    ? 'Add a profile photo — it’s the #1 way to get matches'
                    : 'Looking good! Tap to change',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            _label('I am a'),
            _SegToggle(
              options: const {'foreigner': 'Foreigner', 'local': 'Filipina/o'},
              value: _role,
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 16),
            _label('Gender'),
            _SegToggle(
              options: const {
                'male': 'Male',
                'female': 'Female',
                'other': 'Other'
              },
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Display name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Age'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _country,
                    decoration: const InputDecoration(hintText: 'Country'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _city,
              decoration: const InputDecoration(hintText: 'City'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _languages,
              decoration:
                  const InputDecoration(hintText: 'Languages (e.g. English, Tagalog)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Short bio'),
            ),
            const SizedBox(height: 20),
            _label('Interests'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interestChoices.map((t) {
                final on = _interests.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: on,
                  showCheckmark: false,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  selectedColor: AppColors.primary,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: on
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(
                    () => on ? _interests.remove(t) : _interests.add(t),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _label('Prompts'),
            Text('A great conversation starter — the best way to get replies.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline, fontSize: 13)),
            const SizedBox(height: 8),
            for (var i = 0; i < _prompts.length; i++)
              _PromptCard(
                prompt: _prompts[i],
                onDelete: () => setState(() => _prompts.removeAt(i)),
              ),
            if (_prompts.length < 3)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _addPrompt,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Add prompt'),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(label: 'Start meeting people', onPressed: _save),
          ],
        ),
      ),
    );
  }

  Future<void> _addPrompt() async {
    final used = _prompts.map((p) => p.question).toSet();
    final available =
        kPromptQuestions.where((q) => !used.contains(q)).toList();
    if (available.isEmpty) return;
    final question = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Pick a prompt',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            for (final q in available)
              ListTile(title: Text(q), onTap: () => Navigator.pop(ctx, q)),
          ],
        ),
      ),
    );
    if (question == null || !mounted) return;
    final controller = TextEditingController();
    final answer = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(question),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Your answer…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (answer == null || answer.isEmpty) return;
    setState(
        () => _prompts.add(ProfilePrompt(question: question, answer: answer)));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
      );
}

/// Tappable avatar with a camera badge — the onboarding photo step. Shows the
/// picked image once chosen, else a gradient placeholder prompting a photo.
class _PhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;
  const _PhotoPicker({required this.bytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: bytes == null ? 'Add profile photo' : 'Change profile photo',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                image: bytes != null
                    ? DecorationImage(
                        image: MemoryImage(bytes!), fit: BoxFit.cover)
                    : null,
              ),
              child: bytes == null
                  ? const Icon(LucideIcons.camera, color: Colors.white, size: 34)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                child: const Icon(LucideIcons.plus,
                    color: AppColors.primary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final ProfilePrompt prompt;
  final VoidCallback onDelete;
  const _PromptCard({required this.prompt, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prompt.question,
                      style: TextStyle(fontSize: 12.5, color: cs.outline)),
                  const SizedBox(height: 3),
                  Text(prompt.answer,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegToggle extends StatelessWidget {
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _SegToggle({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.entries.map((e) {
          final on = e.key == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: on ? AppColors.brandGradient : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: on ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
