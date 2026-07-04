import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_prefs.dart';

/// Backend config for Babaero.
///
/// Targets Babaero's OWN isolated local Supabase stack on the Oracle box
/// (project `babaero`, API on :54331) — fully separate from the recipewiser
/// stack (:54321). Tables live in the dedicated `babaero` Postgres schema.
///
/// Values are overridable at build time via --dart-define so the same code
/// runs from an emulator (10.0.2.2), a LAN device, or a local web build.
class SupabaseConfig {
  SupabaseConfig._();

  /// Babaero's local Supabase API gateway (Kong) on the Oracle box.
  /// Android emulator → 10.0.2.2, physical device → the box's LAN IP.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54331',
  );

  /// Local publishable key from `supabase status`. Public by design.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  /// Dedicated Postgres schema for Babaero (exposed via PostgREST db-schemas).
  static const String schema = 'babaero';

  /// Optional shared secret sent on every request as `X-Babaero-Access`.
  /// When the backend is reached through a gated tunnel, only clients that
  /// send this header get through — i.e. only this app. Empty by default.
  static const String accessSecret =
      String.fromEnvironment('ACCESS_SECRET', defaultValue: '');

  /// True when a real key is present. When false the app runs in mock mode
  /// (preview repos, no backend calls) — mirrors the recipewiser pattern.
  static bool get isConfigured => publishableKey.isNotEmpty;

  /// Effective values after applying any runtime override (set in [init]).
  static String _effectiveUrl = url;
  static String _effectiveSecret = accessSecret;

  /// The backend URL actually in use (runtime override or compile-time default).
  static String get effectiveUrl => _effectiveUrl;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || !isConfigured) return;
    // A runtime override (set in-app) wins over the compile-time defaults, so
    // the app can follow a tunnel to the local Supabase without a rebuild.
    final (overrideUrl, overrideSecret) = await BackendPrefs.load();
    _effectiveUrl = overrideUrl ?? url;
    _effectiveSecret = overrideSecret ?? accessSecret;
    await Supabase.initialize(
      url: _effectiveUrl,
      publishableKey: publishableKey,
      headers: _effectiveSecret.isEmpty
          ? null
          : {'X-Babaero-Access': _effectiveSecret},
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// PostgREST query builder scoped to the `babaero` schema.
  /// Use for every table read/write: `SupabaseConfig.db.from('profiles')`.
  static SupabaseQuerySchema get db => client.schema(schema);

  static bool get isSignedIn =>
      isConfigured && client.auth.currentSession != null;
}
