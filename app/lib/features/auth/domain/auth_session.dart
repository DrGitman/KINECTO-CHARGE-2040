/// The signed-in wearer, read from the students table. Mock students only in this prototype.
class AuthSession {
  const AuthSession({
    required this.studentId,
    required this.name,
    required this.email,
    required this.jacketId,
    required this.tagId,
  });

  final String studentId;
  final String name;
  final String email;
  final String jacketId;
  final String tagId;

  /// Kept for older callers: the student number.
  String get userId => studentId;

  /// "J. Amupolo" -> "J. Amupolo", "Ndapandula Shipanga" -> "Ndapandula".
  String get greetingName {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return name;
    return parts.first.endsWith('.') ? name : parts.first;
  }

  /// "JA" for J. Amupolo.
  String get initials {
    final letters = name
        .replaceAll('.', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .toList();
    if (letters.isEmpty) return '?';
    return letters.length == 1 ? letters.first : letters.first + letters.last;
  }
}
