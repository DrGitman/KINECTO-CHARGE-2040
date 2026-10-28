import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend.dart';
import '../../../core/clock.dart';
import '../data/mock_jacket_repository.dart';
import '../data/supabase_jacket_repository.dart';
import '../domain/jacket_repository.dart';
import '../domain/jacket_status.dart';

final jacketRepositoryProvider = Provider<JacketRepository>(
  (ref) => Backend.isConfigured
      ? SupabaseJacketRepository(
          ref.watch(supabaseClientProvider),
          Backend.jacketId,
        )
      : MockJacketRepository(ref.watch(clockProvider)),
);

final jacketStatusProvider = StreamProvider<JacketStatus>(
  (ref) => ref.watch(jacketRepositoryProvider).watchStatus(),
);
