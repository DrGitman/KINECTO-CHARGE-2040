import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/clock.dart';
import '../../../core/formatting/date_labels.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/load_error_view.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../core/widgets/tab_page.dart';
import '../domain/fault.dart';
import 'fault_copy.dart';
import 'faults_controller.dart';
import 'faults_filter.dart';
import 'widgets/fault_log_entry.dart';

/// Colour-coded fault timeline with month and subsystem filters (board 04, screen 10).
class FaultsScreen extends ConsumerWidget {
  const FaultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faults = ref.watch(faultsControllerProvider);
    final filter = ref.watch(faultsFilterProvider);
    final now = ref.watch(clockProvider)();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TabPage.sidePadding,
              16,
              TabPage.sidePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.faultsTab,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SimulatedBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                _MonthPicker(filter: filter),
                const SizedBox(height: 8),
                _SubsystemChips(selected: filter.subsystem),
              ],
            ),
          ),
          Expanded(
            child: faults.when(
              data: (all) => _FaultList(
                faults: all.where(filter.accepts).toList(),
                now: now,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => LoadErrorView(
                onRetry: () => ref.invalidate(faultsControllerProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.filter});

  final FaultsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(faultsFilterProvider.notifier);
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            DateLabels.month(filter.month),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton(
          tooltip: AppStrings.previousMonth,
          onPressed: () => controller.shiftMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: AppStrings.nextMonth,
          onPressed: () => controller.shiftMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SubsystemChips extends ConsumerWidget {
  const _SubsystemChips({required this.selected});

  final FaultSubsystem? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(faultsFilterProvider.notifier);
    final options = <FaultSubsystem?>[null, ...FaultSubsystem.values];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  option == null
                      ? AppStrings.faultsAll
                      : FaultCopy.subsystemLabel(option),
                ),
                selected: option == selected,
                onSelected: (_) => controller.showSubsystem(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _FaultList extends StatelessWidget {
  const _FaultList({required this.faults, required this.now});

  final List<Fault> faults;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (faults.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noFaultsThisMonth,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return ListView.builder(
      padding: TabPage.listPadding,
      itemCount: faults.length,
      itemBuilder: (context, index) => FaultLogEntry(
        fault: faults[index],
        now: now,
        onTap: () => context.push(AppRoutes.faultDetailFor(faults[index].id)),
      ),
    );
  }
}
