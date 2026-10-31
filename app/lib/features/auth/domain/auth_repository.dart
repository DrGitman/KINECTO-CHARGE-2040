import 'auth_session.dart';

abstract interface class AuthRepository {
  /// Checks the NUST email and returns the 6-digit code. Email delivery is not connected in
  /// this prototype, so the code is shown on the verify screen.
  /// Throws [AuthException] when the email cannot sign in.
  Future<String> requestCode(String email);

  /// Throws [AuthException] when the code is wrong.
  Future<AuthSession> verifyCode(String email, String code);

  /// The saved wearer again after the app restarts, null when they are gone.
  Future<AuthSession?> restore(String studentId);

  Future<void> signOut();
}

enum AuthProblem { notNust, unknownEmail, noJacket, wrongCode, offline }

class AuthException implements Exception {
  const AuthException(this.problem);

  final AuthProblem problem;

  @override
  String toString() => 'AuthException: ${problem.name}';
}

/// Only NUST institutional emails can sign in.
bool isNustEmail(String email) =>
    RegExp(r'^[a-z0-9._-]+@(students\.)?nust\.na$').hasMatch(email.trim().toLowerCase());
