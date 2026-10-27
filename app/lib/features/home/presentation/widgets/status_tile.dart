import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pastel tile with one label and one value; one tap opens the matching screen.
class StatusTile extends StatelessWidget {
  const StatusTile({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  static const double _iconSize = 36;

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$label $value',
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        value,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
