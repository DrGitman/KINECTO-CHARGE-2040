import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../theme/app_colors.dart';
import 'pill_label.dart';

/// Every simulated figure must carry this label.
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.simulatedHint,
    child: const PillLabel(
      AppStrings.simulated,
      background: AppColors.gold,
      foreground: AppColors.navy,
    ),
  );
}
