import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import 'call_models.dart';

/// App-level WebRTC signaling over Supabase Realtime broadcast.
///
/// Each signed-in user subscribes to their OWN inbox topic `call-inbox:$uid`
/// and receives every [CallSignal] addressed to them there. To reach a peer we
/// open a lightweight send-only channel to `call-inbox:$peerId`. Because both
/// users are subscribed to their own inbox from app start, there is no
/// ephemeral "message sent before the peer joined" race — the caller still
/// waits for `accept` before creating the offer.
///
/// Broadcast (not a table write) keeps signaling ephemeral: no schema change,
/// nothing to persist, and it never fires the message stream. The durable call
/// LOG is a separate best-effort write (see CallRepository).
///
/// NOTE (security, R3): topic names are keyed by user id, so a determined party
/// could subscribe to a victim's inbox and observe SDP/ICE. R2/R3 should move
/// this to Realtime Authorization (private channels + RLS on realtime.messages).
class CallSignaling {
  final StreamController<CallSignal> _controller =
      StreamController<CallSignal>.broadcast();

  /// All inbound signals addressed to the local user.
  Stream<CallSignal> get signals => _controller.stream;

  RealtimeChannel? _inbox;
  final Map<String, RealtimeChannel> _outbox = {};
  bool _disposed = false;

  String? get _me => SupabaseConfig.client.auth.currentUser?.id;

  /// Subscribe to the local user's inbox. Idempotent; call once signed in.
  void connect() {
    if (_disposed || !SupabaseConfig.isConfigured || _inbox != null) return;
    final me = _me;
    if (me == null) return;
    final ch = SupabaseConfig.client.channel('call-inbox:$me');
    ch.onBroadcast(
      event: 'signal',
      callback: (payload) {
        if (_disposed) return;
        try {
          final sig = CallSignal.fromMap(Map<String, dynamic>.from(payload));
          if (sig.from == me) return; // ignore our own echo
          _controller.add(sig);
        } catch (_) {
          // malformed payload — ignore
        }
      },
    ).subscribe();
    _inbox = ch;
  }

  /// Send a signal to [toUid]'s inbox. Opens (and caches) a send-only channel.
  Future<void> send(String toUid, CallSignal signal) async {
    if (_disposed || !SupabaseConfig.isConfigured) return;
    final ch = _outbox.putIfAbsent(
      toUid,
      () => SupabaseConfig.client.channel('call-inbox:$toUid')..subscribe(),
    );
    try {
      await ch.sendBroadcastMessage(event: 'signal', payload: signal.toMap());
    } catch (e) {
      debugPrint('CallSignaling.send failed: $e');
    }
  }

  /// Drop the cached send-channel to a peer once a call with them is over.
  void closePeer(String toUid) {
    final ch = _outbox.remove(toUid);
    if (ch != null) SupabaseConfig.client.removeChannel(ch);
  }

  void dispose() {
    _disposed = true;
    final inbox = _inbox;
    if (inbox != null) SupabaseConfig.client.removeChannel(inbox);
    for (final ch in _outbox.values) {
      SupabaseConfig.client.removeChannel(ch);
    }
    _outbox.clear();
    _controller.close();
  }
}
