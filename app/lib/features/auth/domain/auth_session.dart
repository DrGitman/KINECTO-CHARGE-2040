/// Signed-in user. Holds a mock ID only, never a real name or student number.
class AuthSession {
  const AuthSession({required this.userId});

  final String userId;
}
