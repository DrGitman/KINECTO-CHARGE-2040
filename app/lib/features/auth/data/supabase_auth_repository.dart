import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// Wearer sign-in against the students table: the NUST email finds the student and their jacket.
/// NUST single sign-on and email delivery are not connected, so the code is shown on screen.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  final Map<String, String> _codes = {};
  final Random _random = Random.secure();

  @override
  Future<String> requestCode(String email) async {
    final address = email.trim().toLowerCase();
    if (!isNustEmail(address)) throw const AuthException(AuthProblem.notNust);
    final row = await _find(address);
    if (row == null) throw const AuthException(AuthProblem.unknownEmail);
    if ((row['jacket_id'] as String?)?.isNotEmpty != true) {
      throw const AuthException(AuthProblem.noJacket);
    }
    final code = List.generate(6, (_) => _random.nextInt(10)).join();
    _codes[address] = code;
    return code;
  }

  @override
  Future<AuthSession> verifyCode(String email, String code) async {
    final address = email.trim().toLowerCase();
    if (_codes[address] != code) throw const AuthException(AuthProblem.wrongCode);
    final row = await _find(address);
    if (row == null) throw const AuthException(AuthProblem.unknownEmail);
    _codes.remove(address);
    return _session(row);
  }

  @override
  Future<AuthSession?> restore(String studentId) async {
    final row = await _client
        .from('students')
        .select('id, name, email, jacket_id, tag_id')
        .eq('id', studentId)
        .maybeSingle();
    if (row == null || (row['jacket_id'] as String?)?.isNotEmpty != true) {
      return null;
    }
    return _session(row);
  }

  @override
  Future<void> signOut() async {}

  Future<Map<String, dynamic>?> _find(String address) async {
    try {
      final rows = await _client
          .from('students')
          .select('id, name, email, jacket_id, tag_id')
          .eq('email', address)
          .order('id')
          .limit(1);
      return rows.isEmpty ? null : rows.first;
    } on PostgrestException {
      throw const AuthException(AuthProblem.offline);
    } on Exception {
      throw const AuthException(AuthProblem.offline);
    }
  }

  static AuthSession _session(Map<String, dynamic> row) => AuthSession(
    studentId: row['id'] as String,
    name: row['name'] as String,
    email: (row['email'] as String?) ?? '',
    jacketId: row['jacket_id'] as String,
    tagId: (row['tag_id'] as String?) ?? '',
  );
}
