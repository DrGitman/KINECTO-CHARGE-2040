import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pill_label.dart';
import '../../../../core/widgets/simulated_badge.dart';

/// Navy card with the greeting and one hero line driven by open faults.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.now,
    required this.openFaultCount,
    required this.jacketId,
  });

  static const int _afternoonFromHour = 12;
  static const int _eveningFromHour = 18;

  final DateTime now;
  final int openFaultCount;
  final String jacketId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _greeting(),
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ),
              const SimulatedBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            heroLine(openFaultCount),
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          PillLabel(
            AppStrings.pairedJacket(jacketId),
            background: Colors.white24,
            foreground: Colors.white,
          ),
        ],
      ),
    );
  }

  static String heroLine(int openFaultCount) => switch (openFaultCount) {
    0 => AppStrings.heroAllGood,
    1 => AppStrings.heroOneFault,
    _ => AppStrings.heroFaults(openFaultCount),
  };

  String _greeting() {
    if (now.hour < _afternoonFromHour) return AppStrings.greetingMorning;
    if (now.hour < _eveningFromHour) return AppStrings.greetingAfternoon;
    return AppStrings.greetingEvening;
  }
}
