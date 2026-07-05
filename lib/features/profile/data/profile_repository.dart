import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../discover/data/profile_models.dart';

/// Reads/writes the signed-in member's own `babaero.profiles` row.
class ProfileRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  Future<Profile?> getMine() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await SupabaseConfig.db
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  /// Create or update the own profile. Only non-null fields are written.
  Future<void> upsert({
    required String name,
    int? age,
    String? gender,
    String? role,
    String? country,
    String? city,
    String? bio,
    String? languages,
    List<String>? interests,
    List<ProfilePrompt>? prompts,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('profiles').upsert({
      'id': uid,
      'name': name,
      'age': ?age,
      'gender': ?gender,
      'role': ?role,
      'country': ?country,
      'city': ?city,
      'bio': ?bio,
      'languages': ?languages,
      'interests': ?interests,
      'prompts': ?prompts?.map((p) => p.toMap()).toList(),
      'last_active': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Upload an image to the member's avatar folder and make it the PRIMARY
  /// photo, keeping any existing gallery photos. Returns the public URL.
  Future<String?> uploadAvatar(Uint8List bytes, {String ext = 'jpg'}) =>
      addPhoto(bytes, ext: ext, makePrimary: true);

  /// Upload a photo and add it to the member's gallery. [makePrimary] puts it
  /// first (so it becomes the avatar); otherwise it's appended to the end.
  /// Returns the new public URL, or null when not signed in.
  Future<String?> addPhoto(
    Uint8List bytes, {
    String ext = 'jpg',
    bool makePrimary = false,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = SupabaseConfig.client.storage.from('avatars');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );
    final url = storage.getPublicUrl(path);
    final current = await _currentPhotos(uid);
    final next = makePrimary ? [url, ...current] : [...current, url];
    await _writePhotos(uid, next);
    return url;
  }

  /// Remove [url] from the gallery (and best-effort delete the storage object).
  Future<void> removePhoto(String url) async {
    final uid = _uid;
    if (uid == null) return;
    final current = await _currentPhotos(uid);
    await _writePhotos(uid, [
      for (final p in current)
        if (p != url) p,
    ]);
    final objectPath = _storagePath(url);
    if (objectPath != null) {
      try {
        await SupabaseConfig.client.storage.from('avatars').remove([objectPath]);
      } catch (_) {
        // orphaned object is harmless; the gallery no longer references it.
      }
    }
  }

  /// Move [url] to the front of the gallery so it becomes the avatar.
  Future<void> setPrimaryPhoto(String url) async {
    final uid = _uid;
    if (uid == null) return;
    final current = await _currentPhotos(uid);
    if (!current.contains(url)) return;
    await _writePhotos(uid, [
      url,
      for (final p in current)
        if (p != url) p,
    ]);
  }

  Future<List<String>> _currentPhotos(String uid) async {
    final row = await SupabaseConfig.db
        .from('profiles')
        .select('photos')
        .eq('id', uid)
        .maybeSingle();
    return (row?['photos'] as List?)?.cast<String>() ?? const [];
  }

  Future<void> _writePhotos(String uid, List<String> photos) async {
    await SupabaseConfig.db
        .from('profiles')
        .update({'photos': photos}).eq('id', uid);
  }

  /// Derive the `<uid>/<file>` object path from a public avatars URL.
  String? _storagePath(String url) {
    const marker = '/avatars/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    final path = url.substring(i + marker.length);
    return path.isEmpty ? null : path;
  }

  /// Boost: bump last_active so the profile jumps to the top of others' decks
  /// (Discover orders by last_active desc). The visible effect of a boost.
  Future<void> boost() async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('profiles').update({
      'last_active': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<void> setOnline(bool online) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('profiles').update({
      'is_online': online,
      'last_active': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }
}
