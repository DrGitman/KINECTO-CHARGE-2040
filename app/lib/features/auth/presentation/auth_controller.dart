import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(),
);

final authControllerProvider = NotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);

/// Current session, null when signed out.
class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  /// Rethrows [AuthException] so the screen can tell the user.
  Future<void> signIn() async {
    try {
      state = await ref.read(authRepositoryProvider).signIn();
    } on AuthException catch (error) {
      debugPrint('[auth] sign-in failed: ${error.message}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}
