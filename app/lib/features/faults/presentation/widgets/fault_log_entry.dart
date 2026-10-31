import 'package:flutter/material.dart';

import '../../../../core/formatting/date_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/kc_widgets.dart';
import '../../domain/fault.dart';
import '../fault_copy.dart';

/// One row of the faults timeline: a dot on the line, then the coloured card (board 04, Faults log).
class FaultLogEntry extends StatelessWidget {
  const FaultLogEntry({
    super.key,
    required this.fault,
    required this.now,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final Fault fault;
  final DateTime now;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = Theme.of(context).colorScheme.outlineVariant;
    final subtitle = '${FaultCopy.subsystemLabel(fault.subsystem)} · ${DateLabels.day(fault.detectedAt, now)}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: isFirst ? 40 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 40 : null,
                  child: Container(width: 2, color: line),
                ),
                Positioned(
                  top: 32,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fault.isOpen ? const Color(0xFFE5383B) : Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: fault.isOpen ? const Color(0xFFE5383B) : const Color(0xFF9AA3B5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: FaultStyle.tileColor(fault),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Row(
                      children: [
                        IconBubble(
                          icon: fault.isOpen ? Icons.warning_amber_rounded : FaultStyle.icon(fault.subsystem),
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      FaultCopy.of(fault.code).shortTitle,
                                      style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _StatusPill(fault: fault),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(subtitle, style: text.bodySmall?.copyWith(color: AppColors.navy)),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.fault});

  final Fault fault;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
    child: Text(
      FaultCopy.statusLabel(fault.status),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: fault.isOpen ? const Color(0xFFE5383B) : AppColors.navy,
      ),
    ),
  );
}
