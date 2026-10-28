import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/backend.dart';

Future<void> main() async {
  if (Backend.isConfigured) {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(url: Backend.url, anonKey: Backend.anonKey);
  }
  runApp(const ProviderScope(child: KinectoCareApp()));
}
