import 'profile_models.dart';

/// A lightweight, client-side compatibility read between the current member and
/// another profile — shared interests + language overlap, rendered as a % and a
/// short "in common" list. Purely cosmetic/heuristic (no server call); stable
/// per pair so the number doesn't jump between rebuilds.
class Compat {
  final int percent;
  final List<String> sharedInterests;
  final bool sharedLanguage;

  const Compat({
    required this.percent,
    required this.sharedInterests,
    required this.sharedLanguage,
  });

  bool get hasSignal => sharedInterests.isNotEmpty || sharedLanguage;
}

Set<String> _langs(String s) => s
    .toLowerCase()
    .split(RegExp(r'[,/]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toSet();

/// Compute compatibility. Returns null when we don't know the current user's
/// profile yet (so callers can simply hide the badge).
Compat? compatibility(Profile? me, Profile other) {
  if (me == null || me.id == other.id) return null;

  final mine = me.interests.toSet();
  final shared = [for (final i in other.interests) if (mine.contains(i)) i];
  final sharedLang = _langs(me.languages)
      .intersection(_langs(other.languages))
      .isNotEmpty;

  // Base off real signal, plus a stable per-pair jitter so scores feel varied
  // without jumping around.
  var score = 45 + shared.length * 11 + (sharedLang ? 14 : 0);
  var h = 0;
  for (final c in (me.id + other.id).codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  score += h % 16; // 0..15
  score = score.clamp(40, 99);

  return Compat(
    percent: score,
    sharedInterests: shared,
    sharedLanguage: sharedLang,
  );
}
