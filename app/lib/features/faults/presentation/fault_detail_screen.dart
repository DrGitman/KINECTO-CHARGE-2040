import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/clock.dart';
import '../../../core/formatting/date_labels.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/load_error_view.dart';
import '../../../core/widgets/pill_label.dart';
import '../domain/fault.dart';
import 'fault_copy.dart';
import 'faults_controller.dart';

/// What happened, what the jacket did, and one next step (board 04, screen 11).
class FaultDetailScreen extends ConsumerWidget {
  const FaultDetailScreen({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faults = ref.watch(faultsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.faultTitle)),
      body: faults.when(
        data: (all) {
          final fault = all.where((f) => f.id == faultId).firstOrNull;
          if (fault == null) {
            return const Center(child: Text(AppStrings.faultNotFound));
          }
          return _FaultDetail(fault: fault, now: ref.watch(clockProvider)());
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadErrorView(
          onRetry: () => ref.invalidate(faultsControllerProvider),
        ),
      ),
    );
  }
}

class _FaultDetail extends ConsumerWidget {
  const _FaultDetail({required this.fault, required this.now});

  final Fault fault;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = FaultCopy.of(fault.code);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(fault: fault, copy: copy, now: now),
        const SizedBox(height: 12),
        _Section(title: AppStrings.whatHappened, body: copy.whatHappened),
        _Section(title: AppStrings.whatWeDid, body: copy.whatWeDid),
        _Section(title: AppStrings.whatToDo, body: copy.whatToDo),
        if (fault.needsAction) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(AppRoutes.repairs),
            child: const Text(AppStrings.bookAFixButton),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _markResolved(context, ref),
            child: const Text(AppStrings.markResolvedButton),
          ),
        ],
      ],
    );
  }

  Future<void> _markResolved(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(faultsControllerProvider.notifier).markResolved(fault.id);
      if (context.mounted) context.pop();
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.resolveFailed)),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.fault, required this.copy, required this.now});

  final Fault fault;
  final FaultCopy copy;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = [
      FaultCopy.subsystemLabel(fault.subsystem),
      DateLabels.day(fault.detectedAt, now),
      FaultCopy.sourceLabel(fault.source),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FaultStyle.tileColor(fault),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fault.isOpen
                    ? Icons.warning_amber_rounded
                    : FaultStyle.icon(fault.subsystem),
                color: fault.isOpen ? AppColors.alert : AppColors.navy,
              ),
              const Spacer(),
              PillLabel(
                fault.isOpen
                    ? AppStrings.needsAFix
                    : FaultCopy.statusLabel(fault.status),
                foreground: fault.isOpen ? AppColors.alert : AppColors.navy,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            copy.title,
            style: textTheme.titleLarge?.copyWith(color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: textTheme.bodySmall?.copyWith(color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(body, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
