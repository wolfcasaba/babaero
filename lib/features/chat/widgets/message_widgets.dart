import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../discover/data/profile_models.dart';
import '../data/translation_service.dart';

/// "Auto-translation on" banner shown atop a conversation. Shared by the 1:1
/// and group chat threads.
class TranslationBanner extends StatelessWidget {
  const TranslationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.secondary.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.languages, size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-translation on · Tagalog ↔ English',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The message input row (attach photo + optional voice + text field + send).
/// Shared by both threads; [hintText] differs (1:1 vs group). Voice controls
/// only appear when [onMicStart] is provided (1:1 only).
class MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final String hintText;

  /// Voice note controls. When [onMicStart] is null the mic button is hidden.
  final VoidCallback? onMicStart;
  final VoidCallback? onMicStop;
  final VoidCallback? onMicCancel;
  final bool recording;
  final String recordingLabel;

  const MessageComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.hintText,
    this.onAttach,
    this.onMicStart,
    this.onMicStop,
    this.onMicCancel,
    this.recording = false,
    this.recordingLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: recording ? _recordingRow(cs) : _normalRow(cs),
      ),
    );
  }

  Widget _normalRow(ColorScheme cs) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.imagePlus),
          color: AppColors.primary,
          tooltip: 'Send a photo',
          onPressed: onAttach,
        ),
        if (onMicStart != null)
          IconButton(
            icon: const Icon(LucideIcons.mic),
            color: AppColors.primary,
            tooltip: 'Record a voice note',
            onPressed: enabled ? onMicStart : null,
          ),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: hintText,
              fillColor: cs.surfaceContainerHighest,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _circleButton(icon: LucideIcons.send, onTap: enabled ? onSend : null),
      ],
    );
  }

  Widget _recordingRow(ColorScheme cs) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
          tooltip: 'Cancel',
          onPressed: onMicCancel,
        ),
        Expanded(
          child: Row(
            children: [
              const _RecordingDot(),
              const SizedBox(width: 8),
              Text('Recording… $recordingLabel',
                  style: TextStyle(color: cs.onSurface)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _circleButton(icon: LucideIcons.send, onTap: onMicStop),
      ],
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      );
}

/// A playable voice note inside a chat bubble: play/pause + progress + time.
class _VoiceNote extends StatefulWidget {
  final String url;
  final int? durMs;
  final Color tint;
  const _VoiceNote({required this.url, required this.durMs, required this.tint});

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  late Duration _total =
      Duration(milliseconds: widget.durMs ?? 0);

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted && d > Duration.zero) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (_total > Duration.zero && _pos >= _total) {
        await _player.seek(Duration.zero);
      }
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint;
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    final remaining = _playing || _pos > Duration.zero
        ? _pos
        : _total;
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Icon(
              _playing ? LucideIcons.pause : LucideIcons.play,
              color: tint,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: tint.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation(tint),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmt(remaining),
              style: TextStyle(color: tint.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }
}

/// A chat message bubble (image + text + inline translation). Shared by the 1:1
/// and group threads. In group mode ([inGroup] = true) incoming bubbles carry a
/// sender name + leading avatar (shown when [showSender]).
class MessageBubble extends StatelessWidget {
  final bool mine;
  final String body;
  final String? translatedBody;
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDurMs;
  final DateTime createdAt;

  final bool inGroup;
  final Profile? sender;
  final bool showSender;
  final double maxWidthFactor;

  /// Read receipt for the sender's own bubbles (1:1 only). null = don't show a
  /// receipt (incoming bubbles, or group mode); false = sent/unread (single ✓);
  /// true = read by the recipient (double ✓✓ in the brand accent).
  final bool? readReceipt;

  const MessageBubble({
    super.key,
    required this.mine,
    required this.body,
    required this.createdAt,
    this.translatedBody,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDurMs,
    this.inGroup = false,
    this.sender,
    this.showSender = false,
    this.maxWidthFactor = 0.74,
    this.readReceipt,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get _hasVoice => voiceUrl != null && voiceUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showTranslation = translatedBody != null &&
        translatedBody!.isNotEmpty &&
        translationService.detect(body) == 'tl';
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    final onBubble = mine ? Colors.white : cs.onSurface;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * maxWidthFactor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine ? AppColors.brandGradient : null,
        color: mine ? null : cs.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inGroup && !mine && showSender && sender != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                sender!.name,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
          if (_hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  height: 160,
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            if (body.isNotEmpty) const SizedBox(height: 8),
          ],
          if (_hasVoice)
            _VoiceNote(
              url: voiceUrl!,
              durMs: voiceDurMs,
              tint: onBubble,
            ),
          if (body.isNotEmpty)
            Text(body, style: TextStyle(color: onBubble, fontSize: 15)),
          if (showTranslation) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: onBubble.withValues(alpha: 0.2)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.languages,
                    size: 12, color: onBubble.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    translatedBody!,
                    style: TextStyle(
                      color: onBubble.withValues(alpha: 0.85),
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final showAvatarRow = inGroup && !mine;
    return Container(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showAvatarRow)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  child: showSender && sender != null
                      ? ProfileAvatar(
                          photoUrl: sender!.photoUrl,
                          initial: sender!.initial,
                          colorA: sender!.colorA,
                          colorB: sender!.colorB,
                          size: 26,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Flexible(child: bubble),
              ],
            )
          else
            bubble,
          Padding(
            padding:
                EdgeInsets.only(top: 4, left: showAvatarRow ? 38 : 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_time(createdAt),
                    style: TextStyle(fontSize: 11, color: cs.outline)),
                if (mine && readReceipt != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    readReceipt! ? LucideIcons.checkCheck : LucideIcons.check,
                    size: 13,
                    color: readReceipt! ? AppColors.secondary : cs.outline,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
