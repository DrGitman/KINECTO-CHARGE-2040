import 'auth_session.dart';

abstract interface class AuthRepository {
  /// Throws [AuthException] when sign-in fails.
  Future<AuthSession> signIn();

  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
