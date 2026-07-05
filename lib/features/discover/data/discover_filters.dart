import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_models.dart';

const int kMinFilterAge = 18;
const int kMaxFilterAge = 80;

/// Client-side Discover filters. Applied to the browse deck in
/// discoverProfilesProvider — cheap for the ~30-profile deck.
class DiscoverFilters {
  final bool verifiedOnly;
  final bool onlineOnly;
  final int minAge;
  final int maxAge;

  /// null = any gender; else 'male' | 'female' | 'other'.
  final String? gender;

  /// "Passport" — browse a specific city (case-insensitive substring). null = any.
  final String? city;

  const DiscoverFilters({
    this.verifiedOnly = false,
    this.onlineOnly = false,
    this.minAge = kMinFilterAge,
    this.maxAge = kMaxFilterAge,
    this.gender,
    this.city,
  });

  bool get isDefault =>
      !verifiedOnly &&
      !onlineOnly &&
      minAge == kMinFilterAge &&
      maxAge == kMaxFilterAge &&
      gender == null &&
      (city == null || city!.isEmpty);

  /// Number of active (non-default) constraints — shown as a badge.
  int get activeCount =>
      (verifiedOnly ? 1 : 0) +
      (onlineOnly ? 1 : 0) +
      (gender != null ? 1 : 0) +
      ((city != null && city!.isNotEmpty) ? 1 : 0) +
      ((minAge != kMinFilterAge || maxAge != kMaxFilterAge) ? 1 : 0);

  bool matches(Profile p) {
    if (verifiedOnly && !p.verified) return false;
    if (onlineOnly && !p.online) return false;
    if (gender != null && p.gender != null && p.gender != gender) return false;
    if (city != null && city!.isNotEmpty) {
      if (!p.city.toLowerCase().contains(city!.toLowerCase())) return false;
    }
    // Only constrain when the profile declares an age.
    if (p.age > 0 && (p.age < minAge || p.age > maxAge)) return false;
    return true;
  }

  DiscoverFilters copyWith({
    bool? verifiedOnly,
    bool? onlineOnly,
    int? minAge,
    int? maxAge,
    Object? gender = _unset,
    Object? city = _unset,
  }) {
    return DiscoverFilters(
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      gender: gender == _unset ? this.gender : gender as String?,
      city: city == _unset ? this.city : city as String?,
    );
  }
}

const Object _unset = Object();

class DiscoverFiltersNotifier extends Notifier<DiscoverFilters> {
  @override
  DiscoverFilters build() => const DiscoverFilters();

  void toggleVerified() =>
      state = state.copyWith(verifiedOnly: !state.verifiedOnly);
  void toggleOnline() => state = state.copyWith(onlineOnly: !state.onlineOnly);
  void setGender(String? g) => state = state.copyWith(gender: g);
  void setCity(String? c) =>
      state = state.copyWith(city: (c == null || c.trim().isEmpty) ? null : c.trim());
  void setAgeRange(int min, int max) =>
      state = state.copyWith(minAge: min, maxAge: max);
  void set(DiscoverFilters f) => state = f;
  void reset() => state = const DiscoverFilters();
}

final discoverFiltersProvider =
    NotifierProvider<DiscoverFiltersNotifier, DiscoverFilters>(
        DiscoverFiltersNotifier.new);
