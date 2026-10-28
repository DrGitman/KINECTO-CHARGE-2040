import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend.dart';
import '../../../core/clock.dart';
import '../../faults/domain/fault.dart';
import '../../faults/presentation/faults_controller.dart';
import '../../jacket/presentation/jacket_providers.dart';
import '../data/mock_comfort_repository.dart';
import '../data/supabase_comfort_repository.dart';
import '../domain/comfort_limits.dart';
import '../domain/comfort_repository.dart';
import '../domain/comfort_settings.dart';

final comfortRepositoryProvider = Provider<ComfortRepository>(
  (ref) => Backend.isConfigured
      ? SupabaseComfortRepository(
          ref.watch(supabaseClientProvider),
          Backend.jacketId,
        )
      : MockComfortRepository(ref.watch(clockProvider)),
);

final comfortControllerProvider =
    AsyncNotifierProvider<ComfortController, ComfortEditor>(
      ComfortController.new,
    );

/// Inside temperature for the gauge, null while the inside sensor fault is open.
final insideReadingProvider = FutureProvider<double?>((ref) async {
  final jacket = await ref.watch(jacketStatusProvider.future);
  final faults = await ref.watch(faultsControllerProvider.future);
  final sensorSilent = faults.any(
    (fault) => fault.isOpen && fault.code == FaultCode.insideSensorSilent,
  );
  return sensorSilent || jacket.insideC.isNaN ? null : jacket.insideC;
});

/// Last saved settings plus the edits not sent to the jacket yet.
class ComfortEditor {
  const ComfortEditor({
    required this.saved,
    required this.draft,
    this.isSaving = false,
  });

  final ComfortSettings saved;
  final ComfortSettings draft;
  final bool isSaving;

  bool get hasChanges => draft.differsFrom(saved);

  ComfortEditor copyWith({ComfortSettings? draft, bool? isSaving}) =>
      ComfortEditor(
        saved: saved,
        draft: draft ?? this.draft,
        isSaving: isSaving ?? this.isSaving,
      );
}

class ComfortController extends AsyncNotifier<ComfortEditor> {
  @override
  Future<ComfortEditor> build() async {
    final repository = ref.read(comfortRepositoryProvider);
    final subscription = repository.watchSettings().listen(_onRemoteChange);
    ref.onDispose(subscription.cancel);
    final settings = await repository.fetchSettings();
    return ComfortEditor(saved: settings, draft: settings);
  }

  // Changed on the jacket or another device. Edits not saved yet stay in the draft.
  void _onRemoteChange(ComfortSettings remote) {
    final editor = state.value;
    if (editor == null || editor.isSaving) return;
    state = AsyncData(
      ComfortEditor(
        saved: remote,
        draft: editor.hasChanges ? editor.draft : remote,
      ),
    );
  }

  void selectMode(ComfortMode mode) =>
      _edit((draft) => draft.copyWith(mode: mode));

  void stepWarmBelow(int delta) => _edit(
    (draft) => ComfortLimits.canStepWarm(draft, delta)
        ? draft.copyWith(
            warmBelowC: draft.warmBelowC + delta * ComfortLimits.stepC,
          )
        : draft,
  );

  void stepCoolAbove(int delta) => _edit(
    (draft) => ComfortLimits.canStepCool(draft, delta)
        ? draft.copyWith(
            coolAboveC: draft.coolAboveC + delta * ComfortLimits.stepC,
          )
        : draft,
  );

  void setPrewarmEnabled(bool enabled) =>
      _edit((draft) => draft.copyWith(prewarmEnabled: enabled));

  void setPrewarmAt(PrewarmTime time) =>
      _edit((draft) => draft.copyWith(prewarmAt: time));

  Future<void> save() async {
    final editor = state.requireValue;
    state = AsyncData(editor.copyWith(isSaving: true));
    try {
      final saved = await ref
          .read(comfortRepositoryProvider)
          .saveSettings(editor.draft);
      state = AsyncData(ComfortEditor(saved: saved, draft: saved));
    } on InvalidComfortSettingsException catch (error) {
      debugPrint('[comfort] save rejected: $error');
      state = AsyncData(editor);
      rethrow;
    }
  }

  void _edit(ComfortSettings Function(ComfortSettings draft) change) {
    final editor = state.value;
    if (editor == null || editor.isSaving) return;
    state = AsyncData(editor.copyWith(draft: change(editor.draft)));
  }
}
