import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// Stand-in until NUST sign-in is wired. Always signs in the same mock user.
class FakeAuthRepository implements AuthRepository {
  // Same mock student as the Unity lab avatar and the Attendance website.
  static const String mockUserId = 'MOCK-0187';

  @override
  Future<AuthSession> signIn() async => const AuthSession(userId: mockUserId);

  @override
  Future<void> signOut() async {}
}
