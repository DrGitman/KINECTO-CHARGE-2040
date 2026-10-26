import 'package:flutter/material.dart';

import '../../../../core/formatting/date_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pill_label.dart';
import '../../domain/fault.dart';
import '../fault_copy.dart';

/// One row of the faults timeline (board 04, screen 10).
class FaultLogEntry extends StatelessWidget {
  const FaultLogEntry({
    super.key,
    required this.fault,
    required this.now,
    required this.onTap,
  });

  static const double _dotSize = 10;
  static const double _iconSize = 36;

  final Fault fault;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle =
        '${FaultCopy.subsystemLabel(fault.subsystem)} · ${DateLabels.day(fault.detectedAt, now)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fault.isOpen ? AppColors.alert : Colors.transparent,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: FaultStyle.tileColor(fault),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: _iconSize,
                        height: _iconSize,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          FaultStyle.icon(fault.subsystem),
                          size: 20,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FaultCopy.of(fault.code).shortTitle,
                              style: textTheme.titleSmall?.copyWith(
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PillLabel(FaultCopy.statusLabel(fault.status)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
