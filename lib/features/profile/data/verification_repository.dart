import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/supabase/supabase_config.dart';

/// Records photo/video/id verification requests in babaero.verifications.
class VerificationRepository {
  String? get _uid => SupabaseConfig.client.auth.currentUser?.id;

  /// Upload the verification selfie to the PRIVATE `verifications` bucket and
  /// return its storage path (not a public URL — only reviewers can read it).
  Future<String?> uploadEvidence(Uint8List bytes, {String ext = 'jpg'}) async {
    final uid = _uid;
    if (uid == null) return null;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = SupabaseConfig.client.storage.from('verifications');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
      ),
    );
    return path;
  }

  /// Latest request status for the signed-in user, or null if none.
  Future<String?> latestStatus() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await SupabaseConfig.db
        .from('verifications')
        .select('status')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['status'] as String?;
  }

  Future<void> submit(String type, {String? evidence}) async {
    final uid = _uid;
    if (uid == null) return;
    await SupabaseConfig.db.from('verifications').insert({
      'user_id': uid,
      'type': type,
      'status': 'pending',
      'evidence': ?evidence,
    });
  }
}
