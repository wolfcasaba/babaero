import 'package:shared_preferences/shared_preferences.dart';

/// Persists a runtime backend override (URL + access secret) so the app can
/// point at a local Supabase reached through a tunnel whose URL changes,
/// without rebuilding. Empty values → fall back to the compile-time defaults.
class BackendPrefs {
  static const _kUrl = 'backend_url';
  static const _kSecret = 'backend_secret';

  static Future<(String? url, String? secret)> load() async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString(_kUrl);
    final secret = p.getString(_kSecret);
    return (
      (url != null && url.isNotEmpty) ? url : null,
      (secret != null && secret.isNotEmpty) ? secret : null,
    );
  }

  static Future<void> save({required String url, required String secret}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUrl, url.trim());
    await p.setString(_kSecret, secret.trim());
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUrl);
    await p.remove(_kSecret);
  }
}
