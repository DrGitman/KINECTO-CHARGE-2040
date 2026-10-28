import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection. Defaults to the Kinecto project, so a plain `flutter run`
/// (or the IDE Run button) shows the live Virtual Lab jacket. Override with
/// `--dart-define-from-file=supabase.json`, or pass an empty SUPABASE_URL to run offline.
abstract final class Backend {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iqlhmjmzcgbmofrujprt.supabase.co',
  );
  // Publishable key: safe in an app, the database policies decide what it may do.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_06uGwP4Wu1OgHJeTiac-qw_TBSeEsLJ',
  );
  static const String jacketId = String.fromEnvironment(
    'KINECTO_JACKET_ID',
    defaultValue: 'KC-SIM-0001',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Set by main() once Supabase is initialised. Tests never run main(), so they
  /// stay on the SIMULATED mock repositories.
  static bool connected = false;

  // Virtual Lab jackets use the KC-SIM- prefix (docs/contracts/thermal.json).
  static bool get isVirtualJacket => jacketId.startsWith('KC-SIM-');
}

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
