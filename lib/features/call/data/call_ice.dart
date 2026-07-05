/// WebRTC ICE-server configuration for Babaero calls.
///
/// ONE place to swap the TURN provider. STUN alone traverses most consumer
/// (non-symmetric) NATs; a TURN relay is required for symmetric / carrier-grade
/// NAT (common on mobile data). TURN credentials are injected at build time so
/// we never bake secrets into the repo and can swap providers without a code
/// change:
///
///   flutter build apk \
///     --dart-define=TURN_URL=turn:your.turn.host:3478 \
///     --dart-define=TURN_USERNAME=user \
///     --dart-define=TURN_CREDENTIAL=pass
///
/// R1 default = Metered. Get free static creds in ~30s at
/// https://dashboard.metered.ca (20 GB/mo free) and pass them via the defines
/// above. To move to Cloudflare Realtime TURN later, just point TURN_URL/
/// TURN_USERNAME/TURN_CREDENTIAL at the Cloudflare-issued values — nothing else
/// changes. With no TURN define set, calls run STUN-only (works on friendly
/// NATs / same network — enough to demo without any account).
class CallIce {
  CallIce._();

  static const _turnUrl = String.fromEnvironment('TURN_URL');
  static const _turnUser = String.fromEnvironment('TURN_USERNAME');
  static const _turnCred = String.fromEnvironment('TURN_CREDENTIAL');

  /// True when a TURN relay is configured (else STUN-only).
  static bool get hasTurn => _turnUrl.isNotEmpty && _turnUser.isNotEmpty;

  static Map<String, dynamic> get configuration => {
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ],
          },
          if (hasTurn)
            {
              'urls': _turnUrl,
              'username': _turnUser,
              'credential': _turnCred,
            },
        ],
        'sdpSemantics': 'unified-plan',
      };
}
