import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../data/compatibility.dart';
import '../data/profile_models.dart';
import 'compat_badge.dart';

/// The three swipe outcomes. Right = like, left = pass, up = super-like —
/// the Tinder convention members already expect.
enum SwipeAction { like, nope, superLike }

/// Imperative handle so the on-screen action buttons can trigger the exact
/// same fling the drag gesture does. Attach it to a [SwipeDeck] via `controller`.
class SwipeDeckController {
  _SwipeDeckState? _state;

  void _attach(_SwipeDeckState s) => _state = s;
  void _detach(_SwipeDeckState s) {
    if (identical(_state, s)) _state = null;
  }

  bool get canSwipe => _state?._canSwipe ?? false;
  bool get canRewind => _state?._canRewind ?? false;
  void like() => _state?._fling(SwipeAction.like);
  void nope() => _state?._fling(SwipeAction.nope);
  void superLike() => _state?._fling(SwipeAction.superLike);
  void rewind() => _state?._rewind();
}

/// A draggable card deck. Owns its own position in [profiles], fires [onAction]
/// with the dismissed profile after each swipe, and shows [caughtUp] once the
/// deck is exhausted. The next card peeks behind the top one and scales up as
/// the top card is dragged away.
class SwipeDeck extends StatefulWidget {
  final List<Profile> profiles;
  final Profile? me;
  final SwipeDeckController? controller;
  final void Function(Profile profile, SwipeAction action) onAction;
  final void Function(Profile profile) onTapProfile;

  /// Fired when the user rewinds the last swipe — carries the restored profile
  /// and the action being undone (so a like/super-like can be un-recorded).
  final void Function(Profile profile, SwipeAction undone)? onRewind;
  final Widget caughtUp;

  const SwipeDeck({
    super.key,
    required this.profiles,
    required this.onAction,
    required this.onTapProfile,
    required this.caughtUp,
    this.me,
    this.controller,
    this.onRewind,
  });

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  SwipeAction? _committing; // non-null while flinging off; null = spring-back
  int _index = 0;
  int _photoIndex = 0; // which photo of the top card is showing
  SwipeAction? _lastAction; // last committed action, for single-step rewind
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )
      ..addListener(() {
        setState(() {
          _drag = Offset.lerp(
              _from, _to, Curves.easeOutCubic.transform(_anim.value))!;
        });
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onSettled();
      });
  }

  @override
  void didUpdateWidget(SwipeDeck old) {
    super.didUpdateWidget(old);
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _anim.dispose();
    super.dispose();
  }

  bool get _canSwipe => !_anim.isAnimating && _index < widget.profiles.length;

  double get _threshX => (_size.width == 0 ? 400 : _size.width) * 0.26;
  double get _threshY => (_size.height == 0 ? 700 : _size.height) * 0.26;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_anim.isAnimating) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_anim.isAnimating) return;
    if (_drag.dx > _threshX) {
      _fling(SwipeAction.like);
    } else if (_drag.dx < -_threshX) {
      _fling(SwipeAction.nope);
    } else if (_drag.dy < -_threshY) {
      _fling(SwipeAction.superLike);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _committing = null;
    _from = _drag;
    _to = Offset.zero;
    _anim.forward(from: 0);
  }

  void _fling(SwipeAction action) {
    if (!_canSwipe) return;
    _committing = action;
    _from = _drag;
    final w = _size.width == 0 ? 400.0 : _size.width;
    final h = _size.height == 0 ? 700.0 : _size.height;
    _to = switch (action) {
      SwipeAction.like => Offset(w * 1.6, _drag.dy),
      SwipeAction.nope => Offset(-w * 1.6, _drag.dy),
      SwipeAction.superLike => Offset(_drag.dx, -h * 1.6),
    };
    HapticFeedback.mediumImpact();
    _anim.forward(from: 0);
  }

  void _onSettled() {
    final action = _committing;
    if (action != null && _index < widget.profiles.length) {
      final dismissed = widget.profiles[_index];
      _index += 1;
      _lastAction = action; // enable a single rewind of this swipe
      widget.onAction(dismissed, action);
    }
    setState(() {
      _committing = null;
      _drag = Offset.zero;
      _photoIndex = 0; // fresh card starts on its first photo
      _anim.reset();
    });
  }

  bool get _canRewind =>
      !_anim.isAnimating && _index > 0 && _lastAction != null;

  /// Bring the last swiped card back (single step). Clears [_lastAction] so it
  /// can't be rewound twice, and hands the undone action back to the parent.
  void _rewind() {
    if (!_canRewind) return;
    final action = _lastAction!;
    _lastAction = null;
    setState(() {
      _index -= 1;
      _drag = Offset.zero;
      _photoIndex = 0;
    });
    widget.onRewind?.call(widget.profiles[_index], action);
  }

  /// Tap zones on the top card: left third = previous photo, right third = next
  /// photo, middle = open the full profile.
  void _onCardTap(TapUpDetails d, Profile current) {
    final photos = current.photos;
    final w = _size.width == 0 ? 400.0 : _size.width;
    if (photos.length > 1 && d.localPosition.dx < w * 0.33) {
      setState(() => _photoIndex =
          (_photoIndex - 1).clamp(0, photos.length - 1).toInt());
    } else if (photos.length > 1 && d.localPosition.dx > w * 0.66) {
      setState(() => _photoIndex =
          (_photoIndex + 1).clamp(0, photos.length - 1).toInt());
    } else {
      widget.onTapProfile(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final profiles = widget.profiles;
        if (_index >= profiles.length) return widget.caughtUp;

        final current = profiles[_index];
        final next = _index + 1 < profiles.length ? profiles[_index + 1] : null;

        final progress = (_drag.distance / _threshX).clamp(0.0, 1.0);
        final rot = (_drag.dx / (_size.width == 0 ? 400 : _size.width)) * 0.22;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Peek of the next card; scales up as the top card leaves.
            if (next != null)
              Transform.scale(
                scale: 0.92 + 0.08 * progress,
                child: _CardWithStamps(profile: next, me: widget.me),
              ),
            // Top, draggable card.
            Transform.translate(
              offset: _drag,
              child: Transform.rotate(
                angle: rot,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onCardTap(d, current),
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: _CardWithStamps(
                    profile: current,
                    me: widget.me,
                    photoIndex: _photoIndex,
                    likeOpacity: _stampOpacity(SwipeAction.like),
                    nopeOpacity: _stampOpacity(SwipeAction.nope),
                    superOpacity: _stampOpacity(SwipeAction.superLike),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _stampOpacity(SwipeAction which) {
    // While flinging via a button there's no drag to read — force the stamp on.
    if (_committing != null) return _committing == which ? 1 : 0;
    return switch (which) {
      SwipeAction.like => (_drag.dx / _threshX).clamp(0.0, 1.0),
      SwipeAction.nope => (-_drag.dx / _threshX).clamp(0.0, 1.0),
      SwipeAction.superLike => (-_drag.dy / _threshY).clamp(0.0, 1.0),
    };
  }
}

/// The profile card visual + the LIKE / NOPE / SUPER decision stamps.
class _CardWithStamps extends StatelessWidget {
  final Profile profile;
  final Profile? me;
  final int photoIndex;
  final double likeOpacity;
  final double nopeOpacity;
  final double superOpacity;
  const _CardWithStamps({
    required this.profile,
    this.me,
    this.photoIndex = 0,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
    this.superOpacity = 0,
  });

  @override
  Widget build(BuildContext context) {
    final compat = compatibility(me, profile);
    final photos = profile.photos;
    final shownPhoto =
        photos.isEmpty ? null : photos[photoIndex.clamp(0, photos.length - 1)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient base (fallback when there's no photo).
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [profile.colorA, profile.colorB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            if (shownPhoto != null)
              CachedNetworkImage(
                imageUrl: shownPhoto,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 250),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              )
            else
              Align(
                child: Text(
                  profile.initial,
                  style: GoogleFonts.poppins(
                    fontSize: 120,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            // Bottom scrim for legibility.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.scrimStrong],
                ),
              ),
            ),
            // Photo carousel segment indicators (only with multiple photos).
            if (photos.length > 1)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i == photoIndex.clamp(0, photos.length - 1)
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Top-right status pill (nudged below the photo segments).
            if (profile.online)
              Positioned(
                top: photos.length > 1 ? 24 : 16,
                right: 16,
                child: const _OnlinePill(),
              ),
            // Top-left compatibility badge.
            if (compat != null && compat.hasSignal)
              Positioned(
                top: 16,
                left: 16,
                child: CompatBadge(percent: compat.percent),
              ),
            // Bottom info.
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${profile.name}, ${profile.age}',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (profile.verified)
                        const Icon(LucideIcons.badgeCheck,
                            color: AppColors.verified, size: 22),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 15, color: Colors.white70),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          // Distance is only shown when we actually have it —
                          // otherwise fall back to city only (no phantom 0 km).
                          profile.distanceKm > 0
                              ? '${profile.city} · ${profile.distanceKm} km away'
                              : profile.city,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: profile.interests
                        .take(3)
                        .map((t) => _InterestChip(t))
                        .toList(),
                  ),
                ],
              ),
            ),
            // Decision stamps (driven by the live drag).
            Positioned(
              top: 34,
              left: 26,
              child: _Stamp(
                  label: 'LIKE',
                  color: AppColors.online,
                  angle: -0.35,
                  opacity: likeOpacity),
            ),
            Positioned(
              top: 34,
              right: 26,
              child: _Stamp(
                  label: 'NOPE',
                  color: AppColors.danger,
                  angle: 0.35,
                  opacity: nopeOpacity),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 140,
              child: Center(
                child: _Stamp(
                    label: 'SUPER',
                    color: AppColors.accent,
                    angle: -0.12,
                    opacity: superOpacity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String label;
  final Color color;
  final double angle;
  final double opacity;
  const _Stamp({
    required this.label,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.01) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circle, size: 9, color: AppColors.online, fill: 1),
          SizedBox(width: 6),
          Text('Online', style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  final String text;
  const _InterestChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}
