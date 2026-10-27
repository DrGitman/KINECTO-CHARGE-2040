import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

/// Big circular gauge of the comfort battery (board 04, screen 8).
class ComfortBatteryGauge extends StatelessWidget {
  const ComfortBatteryGauge({super.key, required this.percent});

  static const double _size = 200;

  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = percent.clamp(0, 100);
    return Semantics(
      label: '${AppStrings.comfortBatteryLabel} $clamped percent',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _size,
        child: CustomPaint(
          painter: _ArcPainter(
            fraction: clamped / 100,
            track: theme.colorScheme.outlineVariant,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$clamped%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  AppStrings.comfortBatteryLabel,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.fraction, required this.track});

  // Open at the bottom, like the reference gauge.
  static const double _startAngle = 0.75 * math.pi;
  static const double _sweepAngle = 1.5 * math.pi;
  static const double _strokeWidth = 16;

  final double fraction;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(_strokeWidth / 2);
    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arc, _startAngle, _sweepAngle, false, stroke(track));
    if (fraction > 0) {
      canvas.drawArc(
        arc,
        _startAngle,
        _sweepAngle * fraction,
        false,
        stroke(AppColors.gold),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.track != track;
}
