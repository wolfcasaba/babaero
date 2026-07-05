import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';

/// Realtime "typing…" indicator over a Supabase broadcast channel scoped to one
/// conversation. Sends throttled typing pings and exposes [othersTyping], which
/// flips true when the OTHER member is typing and auto-clears after a short idle.
///
/// Broadcast (not a table write) keeps typing state ephemeral — nothing to
/// persist, no schema change, and it never fires the message stream.
class TypingChannel {
  TypingChannel(this.conversationId);
  final String conversationId;

  /// True while the other participant is actively typing.
  final ValueNotifier<bool> othersTyping = ValueNotifier<bool>(false);

  RealtimeChannel? _channel;
  DateTime? _lastSent;
  Timer? _clearTimer;
  bool _disposed = false;

  String? get _me => SupabaseConfig.client.auth.currentUser?.id;

  void connect() {
    if (!SupabaseConfig.isConfigured || _channel != null) return;
    final ch = SupabaseConfig.client.channel('typing:$conversationId');
    ch.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final uid = payload['uid']?.toString();
        if (uid == null || uid == _me) return; // ignore my own echo
        if (_disposed) return;
        othersTyping.value = true;
        _clearTimer?.cancel();
        _clearTimer = Timer(const Duration(seconds: 4), () {
          if (!_disposed) othersTyping.value = false;
        });
      },
    ).subscribe();
    _channel = ch;
  }

  /// Call on each keystroke; throttled to ~1 ping / 2s so we don't flood.
  void notifyTyping() {
    final me = _me;
    if (_channel == null || me == null) return;
    final now = DateTime.now();
    if (_lastSent != null &&
        now.difference(_lastSent!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSent = now;
    _channel!.sendBroadcastMessage(event: 'typing', payload: {'uid': me});
  }

  void dispose() {
    _disposed = true;
    _clearTimer?.cancel();
    final ch = _channel;
    if (ch != null) {
      SupabaseConfig.client.removeChannel(ch);
    }
    othersTyping.dispose();
  }
}
