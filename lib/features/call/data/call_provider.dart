import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_models.dart';
import 'call_repository.dart';
import 'call_signaling.dart';

/// App-level signaling hub. Lives for the whole signed-in session; HomeShell
/// calls [CallSignaling.connect] once and listens to [incomingInviteProvider].
final callSignalingProvider = Provider<CallSignaling>((ref) {
  final s = CallSignaling();
  ref.onDispose(s.dispose);
  return s;
});

final callRepositoryProvider =
    Provider<CallRepository>((_) => const CallRepository());

/// Emits only `invite` signals — the app watches this to raise the incoming
/// call screen from any tab.
final incomingInviteProvider = StreamProvider<CallSignal>((ref) {
  final signaling = ref.watch(callSignalingProvider);
  return signaling.signals
      .where((s) => s.type == CallSignalType.invite);
});
