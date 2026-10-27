import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/comfort_limits.dart';
import '../comfort_copy.dart';

/// Inside temperature on the 18 to 28 °C comfort scale (board 04, screen 9).
class InsideTemperatureGauge extends StatelessWidget {
  const InsideTemperatureGauge({super.key, required this.insideC});

  static const double _size = 200;

  // Null while the inside sensor is offline.
  final double? insideC;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reading = insideC;
    final value = reading == null
        ? AppStrings.noReading
        : ComfortCopy.degrees(reading.round());
    final caption = reading == null
        ? AppStrings.insideSensorOffline
        : AppStrings.insideNow;

    return Semantics(
      label: '$caption $value',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScaleLabel(ComfortLimits.minC),
          SizedBox.square(
            dimension: _size,
            child: CustomPaint(
              painter: _DialPainter(fraction: _fraction(reading)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      caption,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _ScaleLabel(ComfortLimits.maxC),
        ],
      ),
    );
  }

  static double? _fraction(double? reading) {
    if (reading == null) return null;
    const span = ComfortLimits.maxC - ComfortLimits.minC;
    return ((reading - ComfortLimits.minC) / span).clamp(0.0, 1.0);
  }
}

class _ScaleLabel extends StatelessWidget {
  const _ScaleLabel(this.celsius);

  final int celsius;

  @override
  Widget build(BuildContext context) => Text(
    '$celsius°',
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: AppColors.navy,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.fraction});

  // Same open-bottom arc as the comfort battery gauge on Home.
  static const double _startAngle = 0.75 * math.pi;
  static const double _sweepAngle = 1.5 * math.pi;
  static const int _tickCount = 40;
  static const double _tickLength = 8;
  static const double _ringInset = 22;
  static const double _strokeWidth = 12;
  static const double _knobRadius = 9;
  static const Color _accent = Color(0xFF8C7FD6);

  final double? fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    _paintTicks(canvas, center, outer);

    final ringRadius = outer - _ringInset;
    canvas.drawCircle(center, ringRadius, Paint()..color = Colors.white);

    final arc = Rect.fromCircle(
      center: center,
      radius: ringRadius - _strokeWidth,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arc,
      _startAngle,
      _sweepAngle,
      false,
      stroke..color = AppColors.comfortTile,
    );

    final value = fraction;
    if (value == null) return;
    final sweep = _sweepAngle * value;
    canvas.drawArc(arc, _startAngle, sweep, false, stroke..color = _accent);

    final knobAngle = _startAngle + sweep;
    final knob =
        center +
        Offset(math.cos(knobAngle), math.sin(knobAngle)) * arc.width / 2;
    canvas.drawCircle(knob, _knobRadius, Paint()..color = Colors.white);
    canvas.drawCircle(
      knob,
      _knobRadius,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _paintTicks(Canvas canvas, Offset center, double outer) {
    final tick = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _tickCount; i++) {
      final angle = 2 * math.pi * i / _tickCount;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (outer - _tickLength),
        center + direction * outer,
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
