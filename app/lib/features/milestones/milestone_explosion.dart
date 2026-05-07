import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// Set true during dev to restart animation on hot reload.
// ignore: unused_element
const bool _kDevRestart = bool.fromEnvironment('MILESTONE_DEV', defaultValue: false);

class MilestoneExplosion extends StatefulWidget {
  const MilestoneExplosion({
    super.key,
    required this.value,
    this.onComplete,
  });

  final String value;
  final VoidCallback? onComplete;

  @override
  State<MilestoneExplosion> createState() => _MilestoneExplosionState();
}

class _MilestoneExplosionState extends State<MilestoneExplosion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Timeline constants (ms).
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

  /// Replay the animation from the start.
  void replay() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0→1 over _total ms
        final tMs = t * _total;

        // ── Scale curve ──────────────────────────────────────────────
        // Anticipation: 0.7x  →  Ignition snap: 1.3x  →  Settle: 1.0x
        final double scale;
        if (tMs < _anticipationEnd) {
          scale = 0.7;
        } else if (tMs < _ignitionEnd) {
          final p = (tMs - _anticipationEnd) / (_ignitionEnd - _anticipationEnd);
          scale = Curves.elasticOut.transform(p) * 0.6 + 0.7; // 0.7 → 1.3
        } else if (tMs < _peakEnd) {
          // Slight living "breath" oscillation at peak.
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          scale = 1.3 + 0.03 * _breathe(p);
        } else {
          final p = (tMs - _peakEnd) / (_settleEnd - _peakEnd);
          scale = 1.3 - 0.3 * Curves.easeOut.transform(p); // 1.3 → 1.0
        }

        // ── Glow intensity ────────────────────────────────────────────
        final double glowAlpha;
        if (tMs < _anticipationEnd) {
          glowAlpha = 0.0;
        } else if (tMs < _ignitionEnd) {
          glowAlpha = (tMs - _anticipationEnd) / (_ignitionEnd - _anticipationEnd);
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          glowAlpha = 0.85 + 0.15 * _breathe(p); // breathes between 0.85–1.0
        } else {
          final p = (tMs - _peakEnd) / (_settleEnd - _peakEnd);
          glowAlpha = 1.0 - 0.7 * Curves.easeIn.transform(p); // 1.0 → 0.3
        }

        // ── Color: text fill ─────────────────────────────────────────
        // Anticipation: white/default → Ignition: yellow-white core
        // Settle: slightly warm white
        final Color textColor;
        if (tMs < _ignitionEnd) {
          textColor = Colors.white;
        } else if (tMs < _peakEnd) {
          final p = (tMs - _ignitionEnd) / (_peakEnd - _ignitionEnd);
          textColor = Color.lerp(
            const Color(0xFFFFFFCC), // hot yellow-white
            const Color(0xFFFFE082), // warm amber shimmer
            _shimmerCycle(p, cycles: 3),
          )!;
        } else {
          textColor = const Color(0xFFFFE082); // residual warm amber
        }

        return Transform.scale(
          scale: scale,
          child: _GlowingNumber(
            value: widget.value,
            textColor: textColor,
            glowAlpha: glowAlpha,
          ),
        );
      },
    );
  }

  /// Sine oscillation 0→1→0 over [p] in [0,1], repeating [cycles] times.
  double _breathe(double p) =>
      0.5 + 0.5 * _sin01(p); // 0→1 smooth sine

  double _sin01(double p) =>
      (1 + _sinApprox(p * 2 * 3.14159265)) / 2;

  // Pure-Dart sin approximation (no dart:math import needed).
  double _sinApprox(double x) {
    // Bhaskara I approximation, good enough for animation.
    x = x % (2 * 3.14159265);
    if (x < 0) x += 2 * 3.14159265;
    final sign = x < 3.14159265 ? 1.0 : -1.0;
    final xn = x < 3.14159265 ? x : x - 3.14159265;
    return sign * (4 * xn * (3.14159265 - xn)) /
        (3.14159265 * 3.14159265 * 2.25 - xn * (3.14159265 - xn));
  }

  /// Oscillates 0→1→0 with [cycles] full waves, produces a shimmer ripple.
  double _shimmerCycle(double p, {int cycles = 3}) {
    return 0.5 + 0.5 * _sinApprox(p * cycles * 2 * 3.14159265);
  }
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

  TextStyle _style(Color color, {double? fontSize}) => GoogleFonts.inter(
        fontSize: fontSize ?? _fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        height: 1.0,
      );

  @override
  Widget build(BuildContext context) {
    // Layer order (back → front): deep-red blur, orange blur, yellow blur, white core.
    return Stack(
      alignment: Alignment.center,
      children: [
        // Layer 1 – deep red, wide halo
        _blurredText(
          color: Color.fromRGBO(180, 20, 0, glowAlpha * 0.6),
          blurRadius: 28,
          scale: 1.05,
        ),
        // Layer 2 – orange mid glow
        _blurredText(
          color: Color.fromRGBO(255, 100, 0, glowAlpha * 0.75),
          blurRadius: 16,
          scale: 1.02,
        ),
        // Layer 3 – yellow inner glow
        _blurredText(
          color: Color.fromRGBO(255, 210, 0, glowAlpha * 0.85),
          blurRadius: 8,
          scale: 1.0,
        ),
        // Core text
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
          shadows: [
            Shadow(
              color: color,
              blurRadius: blurRadius,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Anticipation shake — wraps the explosion in a quick pre-ignition tremor
// ─────────────────────────────────────────────────────────────────────────────

/// Full widget that applies the anticipation shake via flutter_animate,
/// then hands off to [MilestoneExplosion] for the main sequence.
class MilestoneExplosionWithShake extends StatelessWidget {
  const MilestoneExplosionWithShake({
    super.key,
    required this.value,
    this.onComplete,
  });

  final String value;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return MilestoneExplosion(value: value, onComplete: onComplete)
        .animate()
        // Shake during anticipation window (0–200 ms), tiny 3 px tremor.
        .shake(
          duration: 180.ms,
          hz: 12,
          offset: const Offset(3, 2),
          curve: Curves.easeOut,
        );
  }
}
