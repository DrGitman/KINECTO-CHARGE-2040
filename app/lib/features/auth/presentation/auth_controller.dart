import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend.dart';
import '../data/fake_auth_repository.dart';
import '../data/session_store.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => Backend.connected
      ? SupabaseAuthRepository(ref.watch(supabaseClientProvider))
      : FakeAuthRepository(),
);

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// The wearer restored by main() before the first frame; null on a fresh install.
final initialSessionProvider = Provider<AuthSession?>((ref) => null);

final authControllerProvider = NotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);

/// Current wearer, null when signed out.
class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => ref.read(initialSessionProvider);

  /// Returns the code to show on the verify screen. Rethrows [AuthException].
  Future<String> requestCode(String email) async {
    try {
      return await ref.read(authRepositoryProvider).requestCode(email);
    } on AuthException catch (error) {
      debugPrint('[auth] code refused: ${error.problem.name}');
      rethrow;
    }
  }

  /// Signs in when the code matches. Rethrows [AuthException].
  Future<void> verifyCode(String email, String code) async {
    final session = await ref.read(authRepositoryProvider).verifyCode(email, code);
    state = session;
    unawaited(ref.read(sessionStoreProvider).write(session.studentId));
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    unawaited(ref.read(sessionStoreProvider).write(null));
    state = null;
  }
}
