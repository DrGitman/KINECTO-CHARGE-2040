import '../../../core/backend.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// Offline stand-in (tests, or a run without Supabase). Same mock student as the Unity avatar.
class FakeAuthRepository implements AuthRepository {
  static const String mockUserId = 'MOCK-0187';
  static const String mockEmail = 'j.amupolo@nust.na';
  static const String mockCode = '482913';

  static const AuthSession mockSession = AuthSession(
    studentId: mockUserId,
    name: 'J. Amupolo',
    email: mockEmail,
    jacketId: Backend.jacketId,
    tagId: 'MOCK-TAG-0187',
  );

  @override
  Future<String> requestCode(String email) async {
    if (!isNustEmail(email)) throw const AuthException(AuthProblem.notNust);
    if (email.trim().toLowerCase() != mockEmail) {
      throw const AuthException(AuthProblem.unknownEmail);
    }
    return mockCode;
  }

  @override
  Future<AuthSession> verifyCode(String email, String code) async {
    if (code != mockCode) throw const AuthException(AuthProblem.wrongCode);
    return mockSession;
  }

  @override
  Future<AuthSession?> restore(String studentId) async =>
      studentId == mockUserId ? mockSession : null;

  @override
  Future<void> signOut() async {}
}
