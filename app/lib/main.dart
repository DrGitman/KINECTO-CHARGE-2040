import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/backend.dart';
import 'features/auth/data/session_store.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthSession? session;
  if (Backend.isConfigured) {
    await Supabase.initialize(url: Backend.url, publishableKey: Backend.anonKey);
    Backend.connected = true;
    // Stay signed in across restarts: the wearer is read again from Supabase.
    final saved = await SessionStore().read();
    if (saved != null) {
      try {
        session = await SupabaseAuthRepository(Supabase.instance.client).restore(saved);
      } on Exception {
        session = null;
      }
    }
  }
  runApp(
    ProviderScope(
      overrides: [initialSessionProvider.overrideWithValue(session)],
      child: const KinectoCareApp(),
    ),
  );
}
