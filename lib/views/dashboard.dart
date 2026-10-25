import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/calendar.dart';
import '../models/workspace.dart';
import '../services/edge_api.dart';
import '../services/insights_controller.dart';
import '../services/supabase_service.dart';
import '../theme_mode_store.dart';
import 'tools/goals_view.dart';
import 'tools/calendar_view.dart';
import 'tools/customer_view.dart';
import 'tools/invoice_view.dart';
import 'tools/ki_assistant_view.dart';
import 'tools/instagram_view.dart';
import 'tools/pipeline_view.dart';
import 'tools/settings_view.dart';
import 'tools/shotlist_view.dart';
import 'tools/tasks_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final InsightsController _insightsController;
  final _service = SupabaseService.fromInitialized();
  CreatorProfile? _profile;
  List<_UpcomingItem> _upcoming = [];
  bool _isLoadingOverview = true;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _insightsController = InsightsController(EdgeApi.fromInitialized());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _loadOverview();
  }

  @override
  void dispose() {
    _insightsController.dispose();
    _clock.cancel();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final profile = await _service.getProfile();
      final results = await Future.wait([
        _service.getCalendarEntries(),
        _service.getTasks(),
      ]);
      final now = DateTime.now();
      final horizon = now.add(const Duration(days: 14));
      final calendarEntries = results[0] as List<CalendarEntry>;
      final tasks = results[1] as List<DashboardTask>;
      final items = <_UpcomingItem>[
        for (final entry in calendarEntries)
          if (!entry.erledigt &&
              !entry.dateTime.isBefore(now) &&
              entry.dateTime.isBefore(horizon))
            _UpcomingItem(
              title: entry.titel,
              dateTime: entry.dateTime,
              kind: entry.typ == CalendarEntryType.task ? 'Aufgabe' : 'Termin',
              icon: entry.typ == CalendarEntryType.task
                  ? Icons.checklist
                  : Icons.event,
            ),
        for (final task in tasks)
          if (task.status != TaskStatus.done &&
              task.dueAt != null &&
              !task.dueAt!.isBefore(now) &&
              task.dueAt!.isBefore(horizon))
            _UpcomingItem(
              title: task.title,
              dateTime: task.dueAt!,
              kind: 'To-do',
              icon: Icons.task_alt,
            ),
      ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (mounted) {
        setState(() {
          _profile = profile;
          _upcoming = items;
        });
        appThemeMode.value = themeModeFromProfile(profile.themeMode);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Dashboard-Übersicht konnte nicht geladen werden: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOverview = false);
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) {
      await _loadOverview();
    }
  }

  Future<void> _toggleTheme() async {
    final next =
        appThemeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    appThemeMode.value = next;
    final profile = _profile;
    if (profile == null) {
      return;
    }
    try {
      await _service.saveProfile(
        CreatorProfile(
          id: profile.id,
          fullName: profile.fullName,
          companyName: profile.companyName,
          companyAddress: profile.companyAddress,
          companyEmail: profile.companyEmail,
          companyPhone: profile.companyPhone,
          taxNumber: profile.taxNumber,
          vatId: profile.vatId,
          bankDetails: profile.bankDetails,
          invoiceNote: profile.invoiceNote,
          smallBusinessDefault: profile.smallBusinessDefault,
          themeMode: profileThemeFromMode(next),
          legalNoticeUrl: profile.legalNoticeUrl,
          privacyUrl: profile.privacyUrl,
        ),
      );
      _profile = CreatorProfile(
        id: profile.id,
        fullName: profile.fullName,
        companyName: profile.companyName,
        companyAddress: profile.companyAddress,
        companyEmail: profile.companyEmail,
        companyPhone: profile.companyPhone,
        taxNumber: profile.taxNumber,
        vatId: profile.vatId,
        bankDetails: profile.bankDetails,
        invoiceNote: profile.invoiceNote,
        smallBusinessDefault: profile.smallBusinessDefault,
        themeMode: profileThemeFromMode(next),
        legalNoticeUrl: profile.legalNoticeUrl,
        privacyUrl: profile.privacyUrl,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Theme-Einstellung konnte nicht gespeichert werden: $error')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abmelden fehlgeschlagen: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <_DashboardTile>[
      _DashboardTile(
        title: 'Pipeline',
        subtitle: 'Projekte planen und verfolgen',
        icon: Icons.view_kanban_outlined,
        onTap: () => _open(const PipelineView()),
      ),
      _DashboardTile(
        title: 'Kunden',
        subtitle: 'Kontakte und Notizen verwalten',
        icon: Icons.people_alt_outlined,
        onTap: () => _open(const CustomerView()),
      ),
      _DashboardTile(
        title: 'Shotlist',
        subtitle: 'Deine Szenen manuell planen',
        icon: Icons.movie_creation_outlined,
        onTap: () => _open(const ShotlistView()),
      ),
      _DashboardTile(
        title: 'Kalender',
        subtitle: 'Aufgaben und Termine organisieren',
        icon: Icons.calendar_month_outlined,
        onTap: () => _open(const CalendarView()),
      ),
      _DashboardTile(
        title: 'Instagram-Zentrale',
        subtitle: 'Echte Meta-Insights abrufen',
        icon: Icons.insights_outlined,
        onTap: () => _open(
          InstagramView(controller: _insightsController),
        ),
      ),
      _DashboardTile(
        title: 'Aufgaben',
        subtitle: 'To-dos planen und nach Status verfolgen',
        icon: Icons.checklist_rtl,
        onTap: () => _open(const TasksView()),
      ),
      _DashboardTile(
        title: 'Ziele & Meilensteine',
        subtitle: 'Fortschritt sichtbar machen',
        icon: Icons.flag_outlined,
        onTap: () => _open(const GoalsView()),
      ),
      _DashboardTile(
        title: 'Rechnungen & Quittungen',
        subtitle: 'Belege erstellen und archivieren',
        icon: Icons.receipt_long_outlined,
        onTap: () => _open(const InvoiceView()),
      ),
      _DashboardTile(
        title: 'Einstellungen',
        subtitle: 'Profil, Equipment und Integrationen',
        icon: Icons.settings_outlined,
        onTap: () => _open(const SettingsView()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Dashboard'),
        actions: [
          IconButton(
            tooltip: appThemeMode.value == ThemeMode.dark
                ? 'Zum hellen Design wechseln'
                : 'Zum dunklen Design wechseln',
            onPressed: _toggleTheme,
            icon: Icon(
              appThemeMode.value == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => _open(const SettingsView()),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'KI-Assistent',
            onPressed: () => _open(
              KiAssistantView(controller: _insightsController),
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: 'Abmelden',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 820
                  ? 3
                  : constraints.maxWidth >= 560
                      ? 2
                      : 1;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: _NextUpCard(
                        items: _upcoming,
                        isLoading: _isLoadingOverview,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Greeting(name: _profile?.fullName ?? ''),
                          const SizedBox(height: 20),
                          Text(
                            'Dein Leben auf einen Blick',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dein kreatives Business, organisiert an einem Ort.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _DashboardTileCard(
                          tile: tiles[index],
                        ),
                        childCount: tiles.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 2.15 : 1.55,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: OutlinedButton.icon(
                        onPressed: () => _open(
                          KiAssistantView(controller: _insightsController),
                        ),
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('KI-Assistent öffnen'),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _DashboardFooter(profile: _profile),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UpcomingItem {
  const _UpcomingItem({
    required this.title,
    required this.dateTime,
    required this.kind,
    required this.icon,
  });

  final String title;
  final DateTime dateTime;
  final String kind;
  final IconData icon;
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 11 => 'Guten Morgen',
      < 17 => 'Guten Tag',
      _ => 'Guten Abend',
    };
    final formatted = DateFormat('EEEE, d. MMMM · HH:mm', 'de_DE').format(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting${name.trim().isEmpty ? '' : ', ${name.trim().split(' ').first}'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(formatted, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.items, required this.isLoading});

  final List<_UpcomingItem> items;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upcoming_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Next Up · nächste 14 Tage',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isLoading)
              const LinearProgressIndicator()
            else if (items.isEmpty)
              const Text('In den nächsten zwei Wochen ist noch nichts geplant.')
            else
              for (final item in items.take(4))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.icon),
                  title: Text(item.title),
                  subtitle: Text(item.kind),
                  trailing: Text(
                    DateFormat('EEE, dd.MM. · HH:mm', 'de_DE')
                        .format(item.dateTime),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DashboardFooter extends StatelessWidget {
  const _DashboardFooter({required this.profile});

  final CreatorProfile? profile;

  Future<void> _openLink(BuildContext context, String url, String label) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('$label-Link bitte in den Einstellungen hinterlegen.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label-Link ist ungültig.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [
        TextButton(
          onPressed: () => _openLink(
            context,
            profile?.legalNoticeUrl ?? '',
            'Impressum',
          ),
          child: const Text('Impressum'),
        ),
        TextButton(
          onPressed: () => _openLink(
            context,
            profile?.privacyUrl ?? '',
            'Datenschutzerklärung',
          ),
          child: const Text('Datenschutzerklärung'),
        ),
      ],
    );
  }
}

class _DashboardTile {
  const _DashboardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _DashboardTileCard extends StatelessWidget {
  const _DashboardTileCard({required this.tile});

  final _DashboardTile tile;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tile.onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(tile.icon, size: 32, color: color),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tile.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(tile.subtitle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
