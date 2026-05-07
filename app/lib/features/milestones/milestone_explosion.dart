import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Set true during dev to restart animation on hot reload.
// ignore: unused_element
const bool _kDevRestart =
    bool.fromEnvironment('MILESTONE_DEV', defaultValue: false);

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

void showMilestoneExplosion(BuildContext context, int streak) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (_) => _MilestoneOverlay(
      value: '$streak',
      onRemove: () => entry?.remove(),
    ),
  );
  Overlay.of(context).insert(entry);
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay — owns the full animation timeline including backdrop fade
// ─────────────────────────────────────────────────────────────────────────────

class _MilestoneOverlay extends StatefulWidget {
  final String value;
  final VoidCallback onRemove;
  const _MilestoneOverlay({required this.value, required this.onRemove});

  @override
  State<_MilestoneOverlay> createState() => _MilestoneOverlayState();
}

class _MilestoneOverlayState extends State<_MilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _anticipationEnd = 200;
  static const int _ignitionEnd = 500;
  static const int _peakEnd = 1200;
  static const int _settleEnd = 2000;
  static const int _total = _settleEnd;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _total),
    )..forward().whenComplete(widget.onRemove);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final tMs = _controller.value * _total;

        // ── Scale ─────────────────────────────────────────────────────
        final double scale;
        if (tMs < _anticipationEnd) {
          scale = 0.7;
        } else if (tMs < _ignitionEnd) {
          final p =
              ((tMs - _anticipationEnd) / (_ignitionEnd - _anticipationEnd))
                  .clamp(0.0, 1.0);
          scale = Curves.elasticOut.transform(p) * 0.6 + 0.7;
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          scale = 1.3 + 0.03 * _breathe(p);
        } else {
          final p =
              ((tMs - _peakEnd) / (_settleEnd - _peakEnd)).clamp(0.0, 1.0);
          scale = 1.3 - 0.3 * Curves.easeOut.transform(p);
        }

        // ── Glow ──────────────────────────────────────────────────────
        final double glowAlpha;
        if (tMs < _anticipationEnd) {
          glowAlpha = 0.0;
        } else if (tMs < _ignitionEnd) {
          glowAlpha =
              (tMs - _anticipationEnd) / (_ignitionEnd - _anticipationEnd);
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          glowAlpha = 0.85 + 0.15 * _breathe(p);
        } else {
          final p =
              ((tMs - _peakEnd) / (_settleEnd - _peakEnd)).clamp(0.0, 1.0);
          glowAlpha = 1.0 - 0.7 * Curves.easeIn.transform(p);
        }

        // ── Text color ────────────────────────────────────────────────
        final Color textColor;
        if (tMs < _ignitionEnd) {
          textColor = Colors.white;
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          textColor = Color.lerp(
            const Color(0xFFFFFFCC),
            const Color(0xFFFFE082),
            _shimmerCycle(p, cycles: 3),
          )!;
        } else {
          textColor = const Color(0xFFFFE082);
        }

        // ── Overall opacity: fades together with the shrink-back ──────
        final double opacity = tMs < _peakEnd
            ? 1.0
            : 1.0 -
                Curves.easeIn.transform(
                    ((tMs - _peakEnd) / (_settleEnd - _peakEnd))
                        .clamp(0.0, 1.0));

        // ── Shake: tremor during anticipation window ───────────────────
        double shakeX = 0, shakeY = 0;
        if (tMs < 180) {
          final p = tMs / 180;
          shakeX = 3 * math.sin(p * 12 * 2 * math.pi) * (1 - p);
          shakeY = 2 * math.sin(p * 12 * 2 * math.pi + math.pi / 4) * (1 - p);
        }

        return Opacity(
          opacity: opacity,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(shakeX, shakeY),
                child: Transform.scale(
                  scale: scale,
                  child: _GlowingNumber(
                    value: widget.value,
                    textColor: textColor,
                    glowAlpha: glowAlpha,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _breathe(double p) => 0.5 + 0.5 * math.sin(p * 2 * math.pi);
  double _shimmerCycle(double p, {int cycles = 3}) =>
      0.5 + 0.5 * math.sin(p * cycles * 2 * math.pi);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layered glow rendering
// ─────────────────────────────────────────────────────────────────────────────

class _GlowingNumber extends StatelessWidget {
  const _GlowingNumber({
    required this.value,
    required this.textColor,
    required this.glowAlpha,
  });

  final String value;
  final Color textColor;
  final double glowAlpha;

  static const _fontSize = 96.0;

  TextStyle _style(Color color, {double? fontSize}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize ?? _fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.0,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _blurredText(
            color: Color.fromRGBO(180, 20, 0, glowAlpha * 0.6),
            blurRadius: 28,
            scale: 1.05),
        _blurredText(
            color: Color.fromRGBO(255, 100, 0, glowAlpha * 0.75),
            blurRadius: 16,
            scale: 1.02),
        _blurredText(
            color: Color.fromRGBO(255, 210, 0, glowAlpha * 0.85),
            blurRadius: 8,
            scale: 1.0),
        Text(value, style: _style(textColor)),
      ],
    );
  }

  Widget _blurredText({
    required Color color,
    required double blurRadius,
    required double scale,
  }) {
    return Transform.scale(
      scale: scale,
      child: Text(
        value,
        style: _style(color).copyWith(
          shadows: [Shadow(color: color, blurRadius: blurRadius)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo-screen widgets
// ─────────────────────────────────────────────────────────────────────────────

class MilestoneExplosion extends StatefulWidget {
  const MilestoneExplosion({super.key, required this.value, this.onComplete});
  final String value;
  final VoidCallback? onComplete;

  @override
  State<MilestoneExplosion> createState() => _MilestoneExplosionState();
}

class _MilestoneExplosionState extends State<MilestoneExplosion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const int _anticipationEnd = 200;
  static const int _ignitionEnd = 500;
  static const int _peakEnd = 1200;
  static const int _settleEnd = 2000;
  static const int _total = _settleEnd;

  @override
  void initState() {
    super.initState();
    if (_kDevRestart) Animate.restartOnHotReload = true;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _total),
    )..forward().whenComplete(() => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void replay() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tMs = _controller.value * _total;

        final double scale;
        if (tMs < _anticipationEnd) {
          scale = 0.7;
        } else if (tMs < _ignitionEnd) {
          final p =
              (tMs - _anticipationEnd) / (_ignitionEnd - _anticipationEnd);
          scale = Curves.elasticOut.transform(p.clamp(0.0, 1.0)) * 0.6 + 0.7;
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          scale = 1.3 + 0.03 * (0.5 + 0.5 * math.sin(p * 2 * math.pi));
        } else {
          final p =
              ((tMs - _peakEnd) / (_settleEnd - _peakEnd)).clamp(0.0, 1.0);
          scale = 1.3 - 0.3 * Curves.easeOut.transform(p);
        }

        final double glowAlpha;
        if (tMs < _anticipationEnd) {
          glowAlpha = 0.0;
        } else if (tMs < _ignitionEnd) {
          glowAlpha =
              (tMs - _anticipationEnd) / (_ignitionEnd - _anticipationEnd);
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          glowAlpha = 0.85 + 0.15 * (0.5 + 0.5 * math.sin(p * 2 * math.pi));
        } else {
          final p =
              ((tMs - _peakEnd) / (_settleEnd - _peakEnd)).clamp(0.0, 1.0);
          glowAlpha = 1.0 - 0.7 * Curves.easeIn.transform(p);
        }

        final Color textColor;
        if (tMs < _ignitionEnd) {
          textColor = Colors.white;
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          final shimmer = 0.5 + 0.5 * math.sin(p * 3 * 2 * math.pi);
          textColor = Color.lerp(
              const Color(0xFFFFFFCC), const Color(0xFFFFE082), shimmer)!;
        } else {
          textColor = const Color(0xFFFFE082);
        }

        return Transform.scale(
          scale: scale,
          child: _GlowingNumber(
              value: widget.value, textColor: textColor, glowAlpha: glowAlpha),
        );
      },
    );
  }
}

/// Wraps [MilestoneExplosion] with a pre-ignition shake (used by the demo screen).
class MilestoneExplosionWithShake extends StatelessWidget {
  const MilestoneExplosionWithShake(
      {super.key, required this.value, this.onComplete});
  final String value;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return MilestoneExplosion(value: value, onComplete: onComplete)
        .animate()
        .shake(
            duration: 180.ms,
            hz: 12,
            offset: const Offset(3, 2),
            curve: Curves.easeOut);
  }
}
