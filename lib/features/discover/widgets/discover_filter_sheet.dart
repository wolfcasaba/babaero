import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../data/discover_filters.dart';

/// Open the Discover filter sheet. Applies to [discoverFiltersProvider] on Apply.
Future<void> showDiscoverFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DiscoverFilters _draft = ref.read(discoverFiltersProvider);
  late final _city = TextEditingController(text: _draft.city ?? '');

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Filters',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _draft.isDefault && _city.text.isEmpty
                    ? null
                    : () => setState(() {
                          _draft = const DiscoverFilters();
                          _city.clear();
                        }),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _label('Show me'),
          _SegToggle(
            options: const {
              '': 'Everyone',
              'female': 'Women',
              'male': 'Men',
            },
            value: _draft.gender ?? '',
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(gender: v.isEmpty ? null : v)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _label('Age'),
              const Spacer(),
              Text('${_draft.minAge}–${_draft.maxAge}',
                  style: TextStyle(color: cs.outline)),
            ],
          ),
          RangeSlider(
            min: kMinFilterAge.toDouble(),
            max: kMaxFilterAge.toDouble(),
            divisions: kMaxFilterAge - kMinFilterAge,
            activeColor: AppColors.primary,
            values: RangeValues(_draft.minAge.toDouble(), _draft.maxAge.toDouble()),
            labels: RangeLabels('${_draft.minAge}', '${_draft.maxAge}'),
            onChanged: (v) => setState(() => _draft =
                _draft.copyWith(minAge: v.start.round(), maxAge: v.end.round())),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _label('Passport'),
              const SizedBox(width: 6),
              Icon(LucideIcons.plane, size: 15, color: cs.outline),
            ],
          ),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Browse a city (e.g. Cebu, Manila)',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text('Verified members only'),
            value: _draft.verifiedOnly,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(verifiedOnly: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text('Online now'),
            value: _draft.onlineOnly,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(onlineOnly: v)),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Apply filters',
            onPressed: () {
              final city = _city.text.trim();
              ref
                  .read(discoverFiltersProvider.notifier)
                  .set(_draft.copyWith(city: city.isEmpty ? null : city));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
      );
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
