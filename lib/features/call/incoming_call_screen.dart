import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/widgets/brand_widgets.dart';
import 'call_screen.dart';
import 'data/call_audio.dart';
import 'data/call_models.dart';
import 'data/call_provider.dart';

/// Full-screen incoming-call prompt raised app-wide when an `invite` arrives
/// while the app is open. Accepting hands off to [CallScreen] as the callee;
/// declining sends a `reject` back. Auto-dismisses if the caller cancels.
///
/// (R2 replaces this app-open delivery with an FCM data message + native
/// CallKit/full-screen intent so a CLOSED app can ring.)
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key, required this.invite});

  final CallSignal invite;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  StreamSubscription? _sub;
  Timer? _ring;
  final _audio = CallAudio();
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Dismiss if the caller cancels/hangs up before we answer.
    _sub = ref
        .read(callSignalingProvider)
        .signals
        .where((s) =>
            s.callId == widget.invite.callId &&
            (s.type == CallSignalType.cancel ||
                s.type == CallSignalType.hangup))
        .listen((_) => _close());
    // Audible ringtone + haptic pulse until answered.
    _audio.incomingRing();
    _ring = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ring?.cancel();
    _audio.dispose();
    super.dispose();
  }

  void _close() {
    if (!mounted) return;
    // pop() (not maybePop) — PopScope canPop:false makes maybePop a no-op.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _accept() {
    if (_handled) return;
    _handled = true;
    _ring?.cancel();
    _audio.stop();
    final inv = widget.invite;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => CallScreen(
        callId: inv.callId,
        peer: inv.callerPeer,
        conversationId: inv.convId ?? '',
        media: inv.media,
        isCaller: false,
      ),
    ));
  }

  void _decline() {
    if (_handled) return;
    _handled = true;
    _ring?.cancel();
    _audio.stop();
    final inv = widget.invite;
    final selfId = SupabaseConfig.client.auth.currentUser?.id ?? '';
    ref.read(callSignalingProvider).send(
          inv.from,
          CallSignal(
            type: CallSignalType.reject,
            callId: inv.callId,
            from: selfId,
          ),
        );
    ref.read(callRepositoryProvider).logStatus(inv.callId, CallStatus.rejected,
        ended: true);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.invite.callerPeer;
    final isVideo = widget.invite.media.isVideo;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _decline();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.nightGradient),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 64),
                Text(
                  isVideo ? 'Incoming video call' : 'Incoming voice call',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 40),
                ProfileAvatar(
                  photoUrl: peer.photoUrl,
                  initial: peer.initial,
                  colorA: peer.colorA,
                  colorB: peer.colorB,
                  size: 132,
                ),
                const SizedBox(height: 24),
                Text(
                  peer.name,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnswerBtn(
                        icon: LucideIcons.phoneOff,
                        label: 'Decline',
                        color: Colors.red,
                        onTap: _decline,
                      ),
                      _AnswerBtn(
                        icon: isVideo ? LucideIcons.video : LucideIcons.phone,
                        label: 'Accept',
                        color: AppColors.online,
                        onTap: _accept,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerBtn extends StatelessWidget {
  const _AnswerBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
