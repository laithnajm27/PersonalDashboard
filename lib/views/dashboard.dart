import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/edge_api.dart';
import '../services/insights_controller.dart';
import 'tools/calendar_view.dart';
import 'tools/customer_view.dart';
import 'tools/ki_assistant_view.dart';
import 'tools/instagram_view.dart';
import 'tools/pipeline_view.dart';
import 'tools/shotlist_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final InsightsController _insightsController;

  @override
  void initState() {
    super.initState();
    _insightsController = InsightsController(EdgeApi.fromInitialized());
  }

  @override
  void dispose() {
    _insightsController.dispose();
    super.dispose();
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Dashboard'),
        actions: [
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
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                ],
              );
            },
          ),
        ),
      ),
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
