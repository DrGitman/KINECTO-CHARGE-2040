import '../../../core/clock.dart';
import '../../jacket/data/mock_jacket_repository.dart';
import '../domain/comfort_limits.dart';
import '../domain/comfort_repository.dart';
import '../domain/comfort_settings.dart';

/// SIMULATED settings until Supabase and the Bluetooth link are wired.
class MockComfortRepository implements ComfortRepository {
  MockComfortRepository(this._clock) : _settings = _seed(_clock());

  static const Duration _lastSaveAgo = Duration(days: 1);

  final Clock _clock;
  ComfortSettings _settings;

  @override
  Future<ComfortSettings> fetchSettings() async => _settings;

  @override
  Future<ComfortSettings> saveSettings(ComfortSettings settings) async {
    ComfortLimits.validate(settings);
    _settings = settings.copyWith(updatedAt: _clock());
    return _settings;
  }

  // Thresholds match warm_below_c and cool_above_c in docs/contracts/thermal.json.
  static ComfortSettings _seed(DateTime now) => ComfortSettings(
    jacketId: MockJacketRepository.jacketId,
    mode: ComfortMode.auto,
    warmBelowC: 19,
    coolAboveC: 26,
    prewarmEnabled: false,
    prewarmAt: const PrewarmTime(7, 30),
    updatedAt: now.subtract(_lastSaveAgo),
    isSimulated: true,
  );
}
