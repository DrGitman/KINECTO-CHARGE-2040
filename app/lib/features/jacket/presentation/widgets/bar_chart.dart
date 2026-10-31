import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ChartBar {
  const ChartBar({required this.label, required this.value});

  final String label;
  final double value;
}

/// Rounded bars that grow into place; an empty day shows short stubs.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.bars, required this.color, this.unit = ''});

  final List<ChartBar> bars;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final top = bars.map((b) => b.value).fold<double>(0, math.max);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.navy);
    return Semantics(
      label: 'Chart, highest ${top.toStringAsFixed(2)} $unit',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: top <= 0 ? 0.04 : math.max(0.04, bar.value / top)),
                          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, f, _) => FractionallySizedBox(
                            heightFactor: f,
                            child: Container(
                              decoration: BoxDecoration(
                                color: bar.value <= 0 ? color.withValues(alpha: 0.3) : color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(bar.label, style: labelStyle, maxLines: 1, overflow: TextOverflow.visible, softWrap: false),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LineSeries {
  const LineSeries({required this.values, required this.color, required this.label});

  final List<double?> values;
  final Color color;
  final String label;
}

/// Two-line chart (inside vs outside) on a soft grid.
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.series});

  final List<LineSeries> series;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _LinePainter(series),
    size: Size.infinite,
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.series);

  final List<LineSeries> series;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.navy.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final all = [for (final s in series) ...s.values.whereType<double>()];
    if (all.isEmpty) return;
    var lo = all.reduce(math.min) - 1;
    var hi = all.reduce(math.max) + 1;
    if (hi - lo < 4) {
      final mid = (hi + lo) / 2;
      lo = mid - 2;
      hi = mid + 2;
    }
    for (final s in series) {
      final n = s.values.length;
      if (n == 0) continue;
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = s.values[i];
        if (v == null) {
          started = false;
          continue;
        }
        final x = n == 1 ? size.width / 2 : size.width * i / (n - 1);
        final y = size.height * (1 - (v - lo) / (hi - lo));
        if (started) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          started = true;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => true;
}
