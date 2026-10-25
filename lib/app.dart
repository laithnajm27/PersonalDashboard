import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'views/auth_view.dart';
import 'views/dashboard.dart';
import 'theme_mode_store.dart';

class PersonalDashboardApp extends StatelessWidget {
  const PersonalDashboardApp({super.key, this.configurationError});

  final String? configurationError;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Personal Dashboard',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: configurationError != null
            ? _ConfigurationErrorScreen(message: configurationError!)
            : const _AuthenticationGate(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seedColor = Color(0xFF777D79);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        surface: isDark ? const Color(0xFF1B1D1C) : const Color(0xFFF8F8F6),
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF101211) : const Color(0xFFF4F4F1),
      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF1B1F1D) : Colors.white,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
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
