import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'views/auth_view.dart';
import 'views/dashboard.dart';

class PersonalDashboardApp extends StatelessWidget {
  const PersonalDashboardApp({super.key, this.configurationError});

  final String? configurationError;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFFB6F36A);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF171918),
      ),
      scaffoldBackgroundColor: const Color(0xFF101211),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    return MaterialApp(
      title: 'Personal Dashboard',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: configurationError != null
          ? _ConfigurationErrorScreen(message: configurationError!)
          : const _AuthenticationGate(),
    );
  }
}

class _AuthenticationGate extends StatelessWidget {
  const _AuthenticationGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const AuthView();
        }
        return const DashboardView();
      },
    );
  }
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.settings_rounded, size: 40),
                    const SizedBox(height: 16),
                    Text('Einrichtung erforderlich',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    SelectableText(message),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
