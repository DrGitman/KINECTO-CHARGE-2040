import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/comfort_settings.dart';
import '../comfort_copy.dart';

/// Auto / Cool / Warm / Off, the selected mode is a navy pill.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  // 48 px minimum touch target (Fitts's law, board 07).
  static const double _height = 48;

  final ComfortMode selected;
  final ValueChanged<ComfortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final mode in ComfortMode.values)
            Expanded(child: _segment(context, mode)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, ComfortMode mode) {
    final isSelected = mode == selected;
    final label = ComfortCopy.modeLabel(mode);
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? AppColors.navy : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: () => onChanged(mode),
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: _height,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
