import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Call ringtones. The caller hears a looping ringback while dialing; the
/// callee hears a looping ringtone until answered; a short one-shot tone plays
/// when a call ends unanswered/declined so the state is audible (Messenger-like
/// feedback). Assets live in assets/sounds/ (audioplayers' default 'assets/'
/// prefix, so the source path omits it).
class CallAudio {
  final AudioPlayer _player = AudioPlayer();

  Future<void> _loop(String asset) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(asset), volume: 1.0);
    } catch (e) {
      debugPrint('CallAudio loop failed: $e');
    }
  }

  /// Looping outbound ringback (caller, while "Calling…").
  Future<void> outgoingRing() => _loop('sounds/outgoing_ring.wav');

  /// Looping inbound ringtone (callee, while the call rings).
  Future<void> incomingRing() => _loop('sounds/incoming_ring.wav');

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Short one-shot tone when a call ends unanswered / declined / unavailable.
  Future<void> endTone() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource('sounds/call_end.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('CallAudio endTone failed: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
