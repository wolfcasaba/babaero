import 'package:dio/dio.dart';

/// Pluggable translation. The app talks to `TranslationService` only; swap the
/// implementation (Google/DeepL/LibreTranslate/LLM edge function) without
/// touching the UI. The bundled [MockTranslationService] works offline for
/// local dev using a small EN↔Tagalog phrase map — good enough to demo the
/// inline-translation UX; a production build injects a real backend.
abstract class TranslationService {
  const TranslationService();

  /// Best-effort language tag of [text]: 'en' or 'tl' (Tagalog).
  String detect(String text);

  /// Translate [text] into [target] ('en'|'tl'). Returns the original when it
  /// is already in the target language or nothing is known.
  Future<String> translate(String text, {required String target});

  /// Convenience: translate to the counterpart language of [text].
  Future<String> toCounterpart(String text) =>
      translate(text, target: detect(text) == 'tl' ? 'en' : 'tl');
}

class MockTranslationService extends TranslationService {
  const MockTranslationService();

  @override
  Future<String> translate(String text, {required String target}) async =>
      translateSync(text, target: target);

  // Common dating-chat phrases, lowercased. Bidirectional via reverse lookup.
  static const Map<String, String> _enToTl = {
    'hello': 'kumusta',
    'hi': 'kumusta',
    'good morning': 'magandang umaga',
    'good evening': 'magandang gabi',
    'good night': 'magandang gabi',
    'how are you': 'kumusta ka',
    'how are you?': 'kumusta ka?',
    'i am fine': 'ayos lang ako',
    'thank you': 'salamat',
    'thank you so much': 'maraming salamat',
    'you are beautiful': 'ang ganda mo',
    'you are pretty': 'ang ganda mo',
    'i like you': 'gusto kita',
    'i love you': 'mahal kita',
    'my love': 'mahal ko',
    'take care': 'ingat ka',
    'see you soon': 'magkita tayo agad',
    'nice to meet you': 'ikinagagalak kong makilala ka',
    'where are you from': 'taga saan ka',
    'what are you doing': 'ano ang ginagawa mo',
    'the weather is nice': 'maganda ang panahon',
    'yes': 'oo',
    'no': 'hindi',
    'maybe': 'siguro',
    'beautiful': 'maganda',
    'friend': 'kaibigan',
    'sorry': 'pasensya na',
    'please': 'pakiusap',
  };

  static final Map<String, String> _tlToEn = {
    for (final e in _enToTl.entries) e.value: e.key,
    'kumusta': 'hello',
    'kumusta ka': 'how are you',
    'salamat': 'thank you',
    'maraming salamat': 'thank you so much',
    'mahal kita': 'i love you',
    'gusto kita': 'i like you',
    'ang ganda mo': 'you are beautiful',
    'ingat ka': 'take care',
    'oo': 'yes',
    'hindi': 'no',
    'maganda ang panahon': 'the weather is nice',
    'ako': 'i',
    'ikaw': 'you',
    'po': '',
  };

  static const _tagalogMarkers = [
    'kumusta', 'salamat', 'mahal', 'maganda', 'ganda', 'ako', 'ikaw', 'po',
    'ang', 'ng', 'mo', 'ka', 'oo', 'hindi', 'gusto', 'ingat', 'kaibigan',
    'magandang', 'siguro', 'tayo', 'naman', 'talaga',
  ];

  @override
  String detect(String text) {
    final words = text.toLowerCase().split(RegExp(r'[^a-zñ]+'));
    final hits = words.where(_tagalogMarkers.contains).length;
    return hits >= 1 ? 'tl' : 'en';
  }

  /// Synchronous phrase-map translation (used directly + as HTTP fallback).
  String translateSync(String text, {required String target}) {
    final source = detect(text);
    if (source == target) return text;
    final map = target == 'tl' ? _enToTl : _tlToEn;

    final lower = text.toLowerCase().trim();
    // Whole-phrase hit first (strip trailing punctuation).
    final stripped = lower.replaceAll(RegExp(r'[.!?,]+$'), '');
    if (map.containsKey(stripped)) {
      return _preserveCase(text, map[stripped]!);
    }

    // Word-by-word fallback; keep unknown tokens as-is.
    final out = <String>[];
    for (final token in text.split(' ')) {
      final key = token.toLowerCase().replaceAll(RegExp(r'[^a-zñ]'), '');
      final punct =
          token.substring(token.length - _trailingPunct(token).length);
      final repl = map[key];
      out.add(repl == null ? token : (repl.isEmpty ? '' : repl + punct));
    }
    final joined = out.where((s) => s.isNotEmpty).join(' ').trim();
    return joined.isEmpty ? text : _capitalize(joined);
  }

  String _trailingPunct(String s) {
    final m = RegExp(r'[.!?,]+$').firstMatch(s);
    return m?.group(0) ?? '';
  }

  String _preserveCase(String original, String translated) {
    final t = _capitalize(translated);
    final trailing = _trailingPunct(original);
    return trailing.isEmpty ? t : t + trailing;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Real translation via MyMemory (free, no API key, EN↔Tagalog). Falls back to
/// the offline phrase map on any network error or empty/quota response, so the
/// app never blocks on translation.
class HttpTranslationService extends TranslationService {
  final Dio _dio;
  final MockTranslationService _fallback;
  final Map<String, String> _cache = {};

  HttpTranslationService({Dio? dio, MockTranslationService? fallback})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
            )),
        _fallback = fallback ?? const MockTranslationService();

  @override
  String detect(String text) => _fallback.detect(text);

  @override
  Future<String> translate(String text, {required String target}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    final source = detect(trimmed);
    if (source == target) return text;

    final cacheKey = '$source|$target|$trimmed';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final res = await _dio.get(
        'https://api.mymemory.translated.net/get',
        queryParameters: {
          'q': trimmed,
          'langpair': '$source|$target',
          // A valid contact email lifts the anonymous quota from 5k to 50k
          // words/day — without it real users hit the limit fast and every
          // message falls back to the tiny offline phrase map (looks broken).
          'de': _quotaEmail,
        },
      );
      final data = res.data;
      final out = (data is Map)
          ? (data['responseData']?['translatedText'] as String?)
          : null;
      final status = (data is Map) ? data['responseStatus'] : null;
      final ok = status == 200 || status == '200' || status == null;
      if (ok &&
          out != null &&
          out.trim().isNotEmpty &&
          !out.toUpperCase().contains('MYMEMORY WARNING') &&
          !out.toUpperCase().contains('QUERY LENGTH LIMIT') &&
          !out.toUpperCase().contains('INVALID EMAIL')) {
        final cleaned = out.trim();
        _cache[cacheKey] = cleaned;
        return cleaned;
      }
    } catch (_) {
      // fall through to offline map
    }
    return _fallback.translateSync(trimmed, target: target);
  }

  /// Contact email attached to MyMemory requests to raise the daily quota.
  /// Overridable at build time so a deployment can point at its own address.
  static const String _quotaEmail = String.fromEnvironment(
    'MYMEMORY_EMAIL',
    defaultValue: 'hello@babaero.app',
  );
}

/// Global instance. Swap for a different backend in main() if needed.
TranslationService translationService = HttpTranslationService();
