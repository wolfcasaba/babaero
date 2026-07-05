import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Whether a call carries video or is voice-only.
enum CallMedia { video, audio }

extension CallMediaX on CallMedia {
  String get wire => name; // 'video' | 'audio'
  bool get isVideo => this == CallMedia.video;
  static CallMedia parse(Object? v) =>
      v?.toString() == 'audio' ? CallMedia.audio : CallMedia.video;
}

/// Persisted status of a call (the `babaero.calls` log row).
enum CallStatus { ringing, accepted, rejected, missed, canceled, ended, failed }

/// UI-side phase of the local call machine.
enum CallPhase { dialing, incoming, connecting, active, ended }

/// The kinds of messages exchanged over the signaling channel.
enum CallSignalType {
  invite,
  accept,
  reject,
  cancel,
  offer,
  answer,
  ice,
  hangup,
  busy,
}

CallSignalType _signalTypeFrom(String? s) => CallSignalType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => CallSignalType.hangup,
    );

/// A minimal descriptor of the person on the other end of a call, enough to
/// render the call/incoming UI without a profile fetch (the invite carries it).
class CallPeer {
  const CallPeer({
    required this.id,
    required this.name,
    this.photoUrl,
    this.initial = '?',
    this.colorA = AppColors.primary,
    this.colorB = AppColors.secondary,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String initial;
  final Color colorA;
  final Color colorB;
}

/// One control/negotiation message on the per-user signaling channel.
///
/// Everything except the media payload (offer/answer/ice) is small; the whole
/// message rides a Supabase Realtime broadcast (ephemeral, no schema write).
class CallSignal {
  const CallSignal({
    required this.type,
    required this.callId,
    required this.from,
    this.convId,
    this.media = CallMedia.video,
    this.fromName,
    this.fromPhoto,
    this.sdp,
    this.sdpType,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    this.reason,
  });

  final CallSignalType type;
  final String callId;

  /// The sender's user id (used to ignore our own echo).
  final String from;

  // invite-only context:
  final String? convId;
  final CallMedia media;
  final String? fromName;
  final String? fromPhoto;

  // offer/answer:
  final String? sdp;
  final String? sdpType;

  // ice:
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  // reject/busy:
  final String? reason;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'callId': callId,
        'from': from,
        if (convId != null) 'convId': convId,
        'media': media.wire,
        if (fromName != null) 'fromName': fromName,
        if (fromPhoto != null) 'fromPhoto': fromPhoto,
        if (sdp != null) 'sdp': sdp,
        if (sdpType != null) 'sdpType': sdpType,
        if (candidate != null) 'candidate': candidate,
        if (sdpMid != null) 'sdpMid': sdpMid,
        if (sdpMLineIndex != null) 'sdpMLineIndex': sdpMLineIndex,
        if (reason != null) 'reason': reason,
      };

  factory CallSignal.fromMap(Map<String, dynamic> m) => CallSignal(
        type: _signalTypeFrom(m['type']?.toString()),
        callId: (m['callId'] ?? '').toString(),
        from: (m['from'] ?? '').toString(),
        convId: m['convId']?.toString(),
        media: CallMediaX.parse(m['media']),
        fromName: m['fromName']?.toString(),
        fromPhoto: m['fromPhoto']?.toString(),
        sdp: m['sdp']?.toString(),
        sdpType: m['sdpType']?.toString(),
        candidate: m['candidate']?.toString(),
        sdpMid: m['sdpMid']?.toString(),
        sdpMLineIndex: (m['sdpMLineIndex'] as num?)?.toInt(),
        reason: m['reason']?.toString(),
      );

  /// The peer descriptor carried by an `invite`.
  CallPeer get callerPeer => CallPeer(
        id: from,
        name: fromName ?? 'Unknown',
        photoUrl: fromPhoto,
        initial:
            (fromName != null && fromName!.isNotEmpty) ? fromName![0].toUpperCase() : '?',
      );
}
