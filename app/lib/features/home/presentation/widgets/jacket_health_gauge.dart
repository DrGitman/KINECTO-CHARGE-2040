import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ticked ring with a gold arc, the number in the middle (board 04, Home).
/// [muted] draws it grey for the "last known" state.
class JacketHealthGauge extends StatelessWidget {
  const JacketHealthGauge({
    super.key,
    required this.percent,
    required this.caption,
    this.muted = false,
    this.size = 220,
  });

  final int percent;
  final String caption;
  final bool muted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = percent.clamp(0, 100);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$caption $clamped percent',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: clamped / 100),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, fraction, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _GaugePainter(
              fraction: fraction,
              muted: muted,
              track: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(fraction * 100).round()}%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: muted ? const Color(0xFF9AA3B5) : null,
                    ),
                  ),
                  Text(caption, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.muted, required this.track});

  // Open at the bottom.
  static const double _start = 0.75 * math.pi;
  static const double _sweep = 1.5 * math.pi;
  static const int _ticks = 36;

  final double fraction;
  final bool muted;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final accent = muted ? const Color(0xFFC9CFDB) : AppColors.gold;

    // Tick marks around the outside, gold up to the value.
    for (var i = 0; i <= _ticks; i++) {
      final t = i / _ticks;
      final a = _start + _sweep * t;
      final dir = Offset(math.cos(a), math.sin(a));
      final paint = Paint()
        ..color = t <= fraction ? accent : track
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + dir * (outer - 10), c + dir * outer, paint);
    }

    final ring = Rect.fromCircle(center: c, radius: outer - 40);
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ring, _start, _sweep, false, stroke(track));
    if (fraction > 0) {
      canvas.drawArc(ring, _start, _sweep * fraction, false, stroke(accent));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.muted != muted || old.track != track;
}

/// Jacket health: comfort battery and energy buffer, minus 15 points per open fault.
int jacketHealth({required int batteryPercent, required int bufferPercent, required int openFaults}) =>
    (0.7 * batteryPercent + 0.3 * bufferPercent - 15 * openFaults).round().clamp(0, 100);
