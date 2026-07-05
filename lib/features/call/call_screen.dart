import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_widgets.dart';
import '../profile/data/profile_provider.dart';
import 'data/call_audio.dart';
import 'data/call_ice.dart';
import 'data/call_models.dart';
import 'data/call_provider.dart';
import 'data/call_signaling.dart';

/// The active-call surface. Owns the full WebRTC lifecycle (renderers, peer
/// connection, media) and drives negotiation over [CallSignaling], filtered to
/// this call's [callId]. Handles both the caller and callee roles.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.callId,
    required this.peer,
    required this.conversationId,
    required this.media,
    required this.isCaller,
  });

  final String callId;
  final CallPeer peer;
  final String conversationId;
  final CallMedia media;
  final bool isCaller;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _audio = CallAudio();

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  StreamSubscription? _sigSub;

  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteDescSet = false;
  bool _hasRemoteVideo = false;

  CallPhase _phase = CallPhase.connecting;
  bool _micOn = true;
  bool _camOn = true;
  bool _ended = false;

  Timer? _ringTimeout;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  CallSignaling get _sig => ref.read(callSignalingProvider);
  String get _selfId => SupabaseConfig.client.auth.currentUser?.id ?? '';

  MediaStreamTrack? get _audioTrack {
    final tracks = _localStream?.getAudioTracks() ?? const [];
    return tracks.isEmpty ? null : tracks.first;
  }

  MediaStreamTrack? get _videoTrack {
    final tracks = _localStream?.getVideoTracks() ?? const [];
    return tracks.isEmpty ? null : tracks.first;
  }

  @override
  void initState() {
    super.initState();
    _camOn = widget.media.isVideo;
    _phase = widget.isCaller ? CallPhase.dialing : CallPhase.connecting;
    _setup();
  }

  Future<void> _setup() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      final constraints = <String, dynamic>{
        'audio': true,
        'video': widget.media.isVideo
            ? {'facingMode': 'user'}
            : false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer.srcObject = _localStream;

      final pc = await createPeerConnection(CallIce.configuration);
      _pc = pc;
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }

      pc.onIceCandidate = (c) {
        if (c.candidate == null) return;
        _sig.send(
          widget.peer.id,
          CallSignal(
            type: CallSignalType.ice,
            callId: widget.callId,
            from: _selfId,
            candidate: c.candidate,
            sdpMid: c.sdpMid,
            sdpMLineIndex: c.sdpMLineIndex,
          ),
        );
      };

      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams.first;
          if (event.track.kind == 'video' && mounted) {
            setState(() => _hasRemoteVideo = true);
          }
        }
      };

      pc.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onConnected();
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          _end(CallStatus.ended);
        }
      };

      _sigSub = _sig.signals
          .where((s) => s.callId == widget.callId)
          .listen(_onSignal);

      if (widget.isCaller) {
        await _sendInvite();
        _audio.outgoingRing(); // ringback while dialing
        // Ring for a while, then give up if unanswered.
        _ringTimeout = Timer(const Duration(seconds: 40), () {
          if (_phase == CallPhase.dialing) {
            _sig.send(widget.peer.id,
                CallSignal(type: CallSignalType.cancel, callId: widget.callId, from: _selfId));
            _end(CallStatus.missed);
          }
        });
      } else {
        // Callee: PC is ready, tell the caller to start offering.
        _sig.send(widget.peer.id,
            CallSignal(type: CallSignalType.accept, callId: widget.callId, from: _selfId));
      }
    } catch (e) {
      debugPrint('Call setup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the call.')),
        );
      }
      _end(CallStatus.failed);
    }
  }

  Future<void> _sendInvite() async {
    final mine = await ref.read(myProfileProvider.future);
    _sig.send(
      widget.peer.id,
      CallSignal(
        type: CallSignalType.invite,
        callId: widget.callId,
        from: _selfId,
        convId: widget.conversationId,
        media: widget.media,
        fromName: mine?.name ?? 'Someone',
        fromPhoto: mine?.photoUrl,
      ),
    );
    ref.read(callRepositoryProvider).logStart(
          callId: widget.callId,
          conversationId: widget.conversationId,
          calleeId: widget.peer.id,
          media: widget.media,
        );
  }

  Future<void> _onSignal(CallSignal s) async {
    if (_ended) return;
    switch (s.type) {
      case CallSignalType.accept:
        if (widget.isCaller && _phase == CallPhase.dialing) {
          _ringTimeout?.cancel();
          _audio.stop(); // callee picked up — stop the ringback
          setState(() => _phase = CallPhase.connecting);
          await _makeOffer();
        }
        break;
      case CallSignalType.offer:
        if (!widget.isCaller) await _answerOffer(s);
        break;
      case CallSignalType.answer:
        if (widget.isCaller) await _applyAnswer(s);
        break;
      case CallSignalType.ice:
        await _addIce(s);
        break;
      case CallSignalType.reject:
        _showEndReason('Call declined');
        _end(CallStatus.rejected);
        break;
      case CallSignalType.busy:
        _showEndReason('${widget.peer.name} is on another call');
        _end(CallStatus.rejected);
        break;
      case CallSignalType.cancel:
      case CallSignalType.hangup:
        _end(CallStatus.ended);
        break;
      case CallSignalType.invite:
        break; // handled app-level, not here
    }
  }

  Future<void> _makeOffer() async {
    final pc = _pc;
    if (pc == null) return;
    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': widget.media.isVideo,
    });
    await pc.setLocalDescription(offer);
    _sig.send(
      widget.peer.id,
      CallSignal(
        type: CallSignalType.offer,
        callId: widget.callId,
        from: _selfId,
        sdp: offer.sdp,
        sdpType: offer.type,
      ),
    );
  }

  Future<void> _answerOffer(CallSignal s) async {
    final pc = _pc;
    if (pc == null || s.sdp == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(s.sdp, s.sdpType));
    _remoteDescSet = true;
    await _drainIce();
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _sig.send(
      widget.peer.id,
      CallSignal(
        type: CallSignalType.answer,
        callId: widget.callId,
        from: _selfId,
        sdp: answer.sdp,
        sdpType: answer.type,
      ),
    );
  }

  Future<void> _applyAnswer(CallSignal s) async {
    final pc = _pc;
    if (pc == null || s.sdp == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(s.sdp, s.sdpType));
    _remoteDescSet = true;
    await _drainIce();
  }

  Future<void> _addIce(CallSignal s) async {
    if (s.candidate == null) return;
    final cand = RTCIceCandidate(s.candidate, s.sdpMid, s.sdpMLineIndex);
    if (!_remoteDescSet) {
      _pendingIce.add(cand);
      return;
    }
    await _pc?.addCandidate(cand);
  }

  Future<void> _drainIce() async {
    for (final c in _pendingIce) {
      await _pc?.addCandidate(c);
    }
    _pendingIce.clear();
  }

  void _onConnected() {
    if (_ended || _phase == CallPhase.active) return;
    _audio.stop(); // media is flowing — no more ringback
    setState(() => _phase = CallPhase.active);
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  // --- controls ---

  void _toggleMic() {
    final track = _audioTrack;
    if (track == null) return;
    setState(() => _micOn = !_micOn);
    track.enabled = _micOn;
  }

  void _toggleCam() {
    final track = _videoTrack;
    if (track == null) return;
    setState(() => _camOn = !_camOn);
    track.enabled = _camOn;
  }

  Future<void> _switchCamera() async {
    final track = _videoTrack;
    if (track != null) await Helper.switchCamera(track);
  }

  void _hangUp() {
    _sig.send(widget.peer.id,
        CallSignal(type: CallSignalType.hangup, callId: widget.callId, from: _selfId));
    _end(CallStatus.ended);
  }

  void _showEndReason(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _end(CallStatus status) async {
    if (_ended) return;
    _ended = true;
    _ringTimeout?.cancel();
    _durationTimer?.cancel();
    await _audio.stop();
    // Audible "not reachable / declined" feedback before we close.
    const negative = {
      CallStatus.missed,
      CallStatus.rejected,
      CallStatus.failed,
    };
    if (negative.contains(status)) {
      await _audio.endTone();
      await Future.delayed(const Duration(milliseconds: 900));
    }
    if (status == CallStatus.ended && _phase == CallPhase.active) {
      ref.read(callRepositoryProvider).logStatus(widget.callId, status, ended: true);
    } else if (widget.isCaller) {
      ref.read(callRepositoryProvider).logStatus(widget.callId, status, ended: true);
    }
    // pop() (not maybePop) — the PopScope has canPop:false, which makes
    // maybePop a no-op, leaving the call un-closable. pop() bypasses it.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _ringTimeout?.cancel();
    _durationTimer?.cancel();
    _sigSub?.cancel();
    _sig.closePeer(widget.peer.id);
    for (final t in _localStream?.getTracks() ?? const []) {
      t.stop();
    }
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _pc?.close();
    _audio.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_phase) {
      case CallPhase.dialing:
        return 'Calling…';
      case CallPhase.incoming:
        return 'Incoming call';
      case CallPhase.connecting:
        return 'Connecting…';
      case CallPhase.active:
        final m = _elapsed.inMinutes.toString().padLeft(2, '0');
        final sec = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return '$m:$sec';
      case CallPhase.ended:
        return 'Call ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRemoteVideo = widget.media.isVideo &&
        _hasRemoteVideo &&
        _phase == CallPhase.active;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Remote video (or avatar backdrop before connect / for voice).
            if (showRemoteVideo)
              RTCVideoView(
                _remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _AvatarBackdrop(peer: widget.peer, status: _statusText),

            // Local preview (only for video calls, when the cam is on).
            if (widget.media.isVideo && _camOn)
              Positioned(
                top: 48,
                right: 16,
                width: 108,
                height: 152,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),

            // Top status bar (name + timer) when we have remote video.
            if (showRemoteVideo)
              Positioned(
                top: 48,
                left: 16,
                child: _NamePill(name: widget.peer.name, status: _statusText),
              ),

            // Controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: _Controls(
                media: widget.media,
                micOn: _micOn,
                camOn: _camOn,
                onMic: _toggleMic,
                onCam: widget.media.isVideo ? _toggleCam : null,
                onSwitch: widget.media.isVideo ? _switchCamera : null,
                onHangUp: _hangUp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarBackdrop extends StatelessWidget {
  const _AvatarBackdrop({required this.peer, required this.status});
  final CallPeer peer;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.nightGradient),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProfileAvatar(
            photoUrl: peer.photoUrl,
            initial: peer.initial,
            colorA: peer.colorA,
            colorB: peer.colorB,
            size: 128,
          ),
          const SizedBox(height: 22),
          Text(peer.name,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(status,
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }
}

class _NamePill extends StatelessWidget {
  const _NamePill({required this.name, required this.status});
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          Text(status,
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.media,
    required this.micOn,
    required this.camOn,
    required this.onMic,
    required this.onCam,
    required this.onSwitch,
    required this.onHangUp,
  });

  final CallMedia media;
  final bool micOn;
  final bool camOn;
  final VoidCallback onMic;
  final VoidCallback? onCam;
  final VoidCallback? onSwitch;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundBtn(
          icon: micOn ? LucideIcons.mic : LucideIcons.micOff,
          active: !micOn,
          onTap: onMic,
        ),
        const SizedBox(width: 18),
        if (onCam != null) ...[
          _RoundBtn(
            icon: camOn ? LucideIcons.video : LucideIcons.videoOff,
            active: !camOn,
            onTap: onCam!,
          ),
          const SizedBox(width: 18),
        ],
        _RoundBtn(
          icon: LucideIcons.phoneOff,
          bg: Colors.red,
          onTap: onHangUp,
          size: 68,
        ),
        if (onSwitch != null) ...[
          const SizedBox(width: 18),
          _RoundBtn(icon: LucideIcons.switchCamera, onTap: onSwitch!),
        ],
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    this.bg,
    this.active = false,
    this.size = 58,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color? bg;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = bg ??
        (active ? Colors.white : Colors.white.withValues(alpha: 0.18));
    final iconColor = (bg != null || active) ? Colors.white : Colors.white;
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              color: active ? Colors.black : iconColor, size: size * 0.42),
        ),
      ),
    );
  }
}
