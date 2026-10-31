import 'package:shared_preferences/shared_preferences.dart';

/// Remembers who is signed in on this phone (the student number only).
class SessionStore {
  static const String _key = 'kinecto.signedInStudent';

  Future<String?> read() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String? studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (studentId == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, studentId);
      }
    } catch (_) {
      // Not available in widget tests; the session then lasts until the app closes.
    }
  }
}
