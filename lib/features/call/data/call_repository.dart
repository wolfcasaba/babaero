import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_config.dart';
import 'call_models.dart';

/// Best-effort durable log of calls in `babaero.calls`.
///
/// Every write is wrapped so a missing migration (or RLS hiccup) degrades to a
/// no-op — the live call itself runs entirely over realtime signaling and does
/// NOT depend on this table. When migration 22 is applied, the log powers call
/// history and (R3) "missed call" chat entries.
class CallRepository {
  const CallRepository();

  bool get _ready => SupabaseConfig.isSignedIn;

  /// Insert a ringing call row when a call starts (caller side).
  Future<void> logStart({
    required String callId,
    required String conversationId,
    required String calleeId,
    required CallMedia media,
  }) async {
    if (!_ready) return;
    final me = SupabaseConfig.client.auth.currentUser?.id;
    if (me == null) return;
    try {
      await SupabaseConfig.db.from('calls').insert({
        'id': callId,
        'conversation_id': conversationId.isEmpty ? null : conversationId,
        'caller_id': me,
        'callee_id': calleeId,
        'media': media.wire,
        'status': CallStatus.ringing.name,
      });
    } catch (e) {
      debugPrint('CallRepository.logStart no-op: $e');
    }
  }

  /// Update the terminal status of a call (either side).
  Future<void> logStatus(String callId, CallStatus status,
      {bool ended = false}) async {
    if (!_ready) return;
    try {
      await SupabaseConfig.db.from('calls').update({
        'status': status.name,
        if (ended) 'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', callId);
    } catch (e) {
      debugPrint('CallRepository.logStatus no-op: $e');
    }
  }
}
