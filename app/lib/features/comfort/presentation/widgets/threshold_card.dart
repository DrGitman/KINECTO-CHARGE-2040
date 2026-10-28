import 'package:flutter/material.dart';

import '../../../../core/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../comfort_copy.dart';

/// Pastel card with one Auto threshold and its minus and plus buttons.
class ThresholdCard extends StatelessWidget {
  const ThresholdCard({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.celsius,
    required this.onLower,
    required this.onRaise,
  });

  static const double _iconSize = 36;

  final Color color;
  final IconData icon;
  final String label;
  final int celsius;
  // Null disables the button at the limit.
  final VoidCallback? onLower;
  final VoidCallback? onRaise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.navy),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: AppColors.navy),
          ),
          Semantics(
            label: '$label ${ComfortCopy.degrees(celsius)}',
            excludeSemantics: true,
            child: Text(
              ComfortCopy.degrees(celsius),
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _StepButton(
                icon: Icons.remove,
                tooltip: '${AppStrings.lower} $label',
                onPressed: onLower,
              ),
              const SizedBox(width: 4),
              _StepButton(
                icon: Icons.add,
                tooltip: '${AppStrings.raise} $label',
                onPressed: onRaise,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      disabledBackgroundColor: Colors.white54,
      disabledForegroundColor: AppColors.navy.withValues(alpha: 0.3),
      minimumSize: const Size.square(40),
    ),
  );
}
