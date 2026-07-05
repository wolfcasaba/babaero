import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, device-scoped app preferences (persisted in shared_preferences).
/// Notification toggles are honored by the (future) push layer; auto-translate
/// is honored right now by the chat/group send flow.
class AppSettings {
  final bool autoTranslate;
  final bool notifyMatches;
  final bool notifyMessages;
  final bool notifyLikes;

  const AppSettings({
    this.autoTranslate = true,
    this.notifyMatches = true,
    this.notifyMessages = true,
    this.notifyLikes = true,
  });

  AppSettings copyWith({
    bool? autoTranslate,
    bool? notifyMatches,
    bool? notifyMessages,
    bool? notifyLikes,
  }) {
    return AppSettings(
      autoTranslate: autoTranslate ?? this.autoTranslate,
      notifyMatches: notifyMatches ?? this.notifyMatches,
      notifyMessages: notifyMessages ?? this.notifyMessages,
      notifyLikes: notifyLikes ?? this.notifyLikes,
    );
  }
}

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _kAutoTranslate = 'set_auto_translate';
  static const _kNotifyMatches = 'set_notify_matches';
  static const _kNotifyMessages = 'set_notify_messages';
  static const _kNotifyLikes = 'set_notify_likes';

  @override
  Future<AppSettings> build() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      autoTranslate: p.getBool(_kAutoTranslate) ?? true,
      notifyMatches: p.getBool(_kNotifyMatches) ?? true,
      notifyMessages: p.getBool(_kNotifyMessages) ?? true,
      notifyLikes: p.getBool(_kNotifyLikes) ?? true,
    );
  }

  Future<void> _persist(String key, bool value, AppSettings next) async {
    state = AsyncData(next);
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<void> setAutoTranslate(bool v) =>
      _persist(_kAutoTranslate, v, _current.copyWith(autoTranslate: v));
  Future<void> setNotifyMatches(bool v) =>
      _persist(_kNotifyMatches, v, _current.copyWith(notifyMatches: v));
  Future<void> setNotifyMessages(bool v) =>
      _persist(_kNotifyMessages, v, _current.copyWith(notifyMessages: v));
  Future<void> setNotifyLikes(bool v) =>
      _persist(_kNotifyLikes, v, _current.copyWith(notifyLikes: v));

  AppSettings get _current => state.value ?? const AppSettings();
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
        AppSettingsNotifier.new);
