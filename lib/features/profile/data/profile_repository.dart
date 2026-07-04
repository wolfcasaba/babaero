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
      'last_active': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Upload an image to the member's avatar folder and set it as the primary
  /// photo. Returns the public URL, or null when not signed in.
  Future<String?> uploadAvatar(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _uid;
    if (uid == null) return null;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = SupabaseConfig.client.storage.from('avatars');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    final url = storage.getPublicUrl(path);
    await SupabaseConfig.db.from('profiles').update({
      'photos': [url],
    }).eq('id', uid);
    return url;
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
