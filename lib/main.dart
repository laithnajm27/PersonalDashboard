import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (url.isEmpty || anonKey.isEmpty) {
    runApp(const PersonalDashboardApp(
      configurationError:
          'SUPABASE_URL und SUPABASE_ANON_KEY müssen beim Build gesetzt werden.',
    ));
    return;
  }

  try {
    await SupabaseService.initialize(url: url, anonKey: anonKey);
    runApp(const PersonalDashboardApp());
  } catch (error) {
    runApp(PersonalDashboardApp(
      configurationError: 'Supabase konnte nicht initialisiert werden: $error',
    ));
  }
}
