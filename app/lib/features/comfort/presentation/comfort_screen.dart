import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_strings.dart';
import '../../../core/clock.dart';
import '../../../core/formatting/date_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/load_error_view.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../domain/comfort_limits.dart';
import '../domain/comfort_settings.dart';
import 'comfort_controller.dart';
import 'comfort_copy.dart';
import 'widgets/inside_temperature_gauge.dart';
import 'widgets/mode_selector.dart';
import 'widgets/threshold_card.dart';

/// Full-screen page pushed above the tabs, with a back button (board 04, screen 9).
class ComfortScreen extends ConsumerWidget {
  const ComfortScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(comfortControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.comfortTitle),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: SimulatedBadge()),
        ],
      ),
      body: editor.when(
        data: (editor) => _ComfortForm(editor: editor),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadErrorView(
          onRetry: () => ref.invalidate(comfortControllerProvider),
        ),
      ),
    );
  }
}

class _ComfortForm extends ConsumerWidget {
  const _ComfortForm({required this.editor});

  static const double _gap = 12;

  final ComfortEditor editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(comfortControllerProvider.notifier);
    final draft = editor.draft;
    final insideC = ref.watch(insideReadingProvider).value;
    final now = ref.watch(clockProvider)();
    final small = Theme.of(context).textTheme.bodySmall;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ModeSelector(selected: draft.mode, onChanged: controller.selectMode),
        const SizedBox(height: _gap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.comfortTile,
            borderRadius: BorderRadius.circular(24),
          ),
          child: InsideTemperatureGauge(insideC: insideC),
        ),
        const SizedBox(height: _gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ThresholdCard(
                  color: AppColors.energyTile,
                  icon: Icons.wb_sunny_outlined,
                  label: AppStrings.warmMeBelow,
                  celsius: draft.warmBelowC,
                  onLower: _step(
                    draft,
                    ComfortLimits.canStepWarm,
                    -1,
                    controller.stepWarmBelow,
                  ),
                  onRaise: _step(
                    draft,
                    ComfortLimits.canStepWarm,
                    1,
                    controller.stepWarmBelow,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ThresholdCard(
                  color: AppColors.cuffTile,
                  icon: Icons.ac_unit,
                  label: AppStrings.coolMeAbove,
                  celsius: draft.coolAboveC,
                  onLower: _step(
                    draft,
                    ComfortLimits.canStepCool,
                    -1,
                    controller.stepCoolAbove,
                  ),
                  onRaise: _step(
                    draft,
                    ComfortLimits.canStepCool,
                    1,
                    controller.stepCoolAbove,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (draft.mode != ComfortMode.auto) ...[
          const SizedBox(height: 8),
          Text(AppStrings.limitsUsedInAuto, style: small),
        ],
        const SizedBox(height: _gap),
        _PrewarmCard(
          settings: draft,
          onToggle: controller.setPrewarmEnabled,
          onPickTime: () =>
              _pickPrewarmTime(context, draft.prewarmAt, controller),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: editor.hasChanges && !editor.isSaving
              ? () => _save(context, controller)
              : null,
          child: editor.isSaving
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : const Text(AppStrings.saveToJacketButton),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.savedAgo(DateLabels.timeAgo(editor.saved.updatedAt, now)),
          style: small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  static VoidCallback? _step(
    ComfortSettings draft,
    bool Function(ComfortSettings, int) canStep,
    int delta,
    void Function(int) step,
  ) => canStep(draft, delta) ? () => step(delta) : null;

  Future<void> _pickPrewarmTime(
    BuildContext context,
    PrewarmTime current,
    ComfortController controller,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked != null) {
      controller.setPrewarmAt(PrewarmTime(picked.hour, picked.minute));
    }
  }

  Future<void> _save(BuildContext context, ComfortController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.save();
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.comfortSaved)),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.comfortSaveFailed)),
      );
    }
  }
}

class _PrewarmCard extends StatelessWidget {
  const _PrewarmCard({
    required this.settings,
    required this.onToggle,
    required this.onPickTime,
  });

  final ComfortSettings settings;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = AppStrings.prewarmBefore(
      ComfortCopy.prewarmTime(settings.prewarmAt),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onPickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Heating stays off by default, the wearer opts in.
                Semantics(
                  label: title,
                  child: Switch(
                    value: settings.prewarmEnabled,
                    onChanged: onToggle,
                  ),
                ),
              ],
            ),
            Text(AppStrings.prewarmNote, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
