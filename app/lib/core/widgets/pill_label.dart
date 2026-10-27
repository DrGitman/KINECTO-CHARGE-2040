import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small rounded label used for status chips and badges.
class PillLabel extends StatelessWidget {
  const PillLabel(
    this.text, {
    super.key,
    this.background = Colors.white,
    this.foreground = AppColors.navy,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: ShapeDecoration(
      color: background,
      shape: const StadiumBorder(),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
