import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../data/mock_jacket_repository.dart';
import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

final jacketRepositoryProvider = Provider<JacketRepository>(
  (ref) => MockJacketRepository(ref.watch(clockProvider)),
);

final jacketStatusProvider = FutureProvider<JacketStatus>(
  (ref) => ref.watch(jacketRepositoryProvider).fetchStatus(),
);
