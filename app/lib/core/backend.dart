import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection, given at build time:
/// `flutter run --dart-define-from-file=supabase.json`.
/// Without it the app runs on the SIMULATED mock repositories.
abstract final class Backend {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String jacketId = String.fromEnvironment(
    'KINECTO_JACKET_ID',
    defaultValue: 'KC-SIM-0001',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  // Virtual Lab jackets use the KC-SIM- prefix (docs/contracts/thermal.json).
  static bool get isVirtualJacket => jacketId.startsWith('KC-SIM-');
}

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
