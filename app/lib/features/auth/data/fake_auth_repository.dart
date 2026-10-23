import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// Stand-in until NUST sign-in is wired. Always signs in the same mock user.
class FakeAuthRepository implements AuthRepository {
  static const String mockUserId = 'STU-MOCK-0001';

  @override
  Future<AuthSession> signIn() async => const AuthSession(userId: mockUserId);

  @override
  Future<void> signOut() async {}
}
