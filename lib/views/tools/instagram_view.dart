import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/insights.dart';
import '../../services/insights_controller.dart';

class InstagramView extends StatefulWidget {
  const InstagramView({required this.controller, super.key});

  final InsightsController controller;

  @override
  State<InstagramView> createState() => _InstagramViewState();
}

class _InstagramViewState extends State<InstagramView>
    with WidgetsBindingObserver {
  String? _error;
  bool _oauthOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExistingConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _oauthOpened) {
      _oauthOpened = false;
      _loadExistingConnection();
    }
  }

  Future<void> _loadExistingConnection() async {
    try {
      final connection = await widget.controller.loadConnection();
      if (connection != null) {
        await widget.controller.connectAndLoad();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Instagram-Verbindung konnte nicht geladen werden: $error');
      }
    }
  }

  Future<void> _connect() async {
    setState(() => _error = null);
    try {
      if (widget.controller.connection == null) {
        await widget.controller.beginInstagramConnection();
        _oauthOpened = true;
      } else {
        await widget.controller.connectAndLoad();
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = 'Meta-Insights konnten nicht geladen werden: $error');
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instagram trennen?'),
        content: const Text(
          'Das gespeicherte Instagram-Zugriffstoken wird aus dem Dashboard entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trennen'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.controller.disconnectInstagram();
      if (mounted) {
        setState(() => _error = null);
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = 'Instagram konnte nicht getrennt werden: $error');
      }
    }
  }

  Future<void> _refreshConnection() async {
    setState(() => _error = null);
    try {
      final connection = await widget.controller.loadConnection();
      if (connection == null) {
        setState(() => _error =
            'Noch kein Instagram-Konto verknüpft. Starte zuerst die Verbindung bei Instagram.');
        return;
      }
      await widget.controller.connectAndLoad();
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Instagram-Verbindung konnte nicht geprüft werden: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final insights = widget.controller.insights;
        return Scaffold(
          appBar: AppBar(title: const Text('Instagram-Zentrale')),
          body: RefreshIndicator(
            onRefresh: _refreshConnection,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.controller.connection != null
                              ? '@${widget.controller.connection!.username}'
                              : insights == null
                                  ? 'Verbinde dein Instagram-Konto'
                                  : insights.username.isEmpty
                                      ? 'Instagram-Insights'
                                      : '@${insights.username}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Die Verbindung wird sicher über die Supabase Edge Function hergestellt. Meta-Zugangsdaten bleiben serverseitig.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              widget.controller.isLoading ? null : _connect,
                          icon: widget.controller.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link),
                          label: Text(
                            widget.controller.isLoading
                                ? 'Instagram wird geladen …'
                                : widget.controller.connection == null
                                    ? 'Instagram-Konto verbinden'
                                    : 'Insights aktualisieren',
                          ),
                        ),
                        if (widget.controller.connection == null) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: widget.controller.isLoading
                                ? null
                                : _refreshConnection,
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              'Nach der Instagram-Freigabe Status aktualisieren',
                            ),
                          ),
                        ],
                        if (widget.controller.connection != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: widget.controller.isLoading
                                ? null
                                : _disconnect,
                            icon: const Icon(Icons.link_off),
                            label: const Text('Konto trennen'),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (insights != null) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 1000
                          ? 4
                          : constraints.maxWidth > 600
                              ? 2
                              : 1;
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 1 ? 3.1 : 1.35,
                        children: [
                          _MetricCard(
                            icon: Icons.people_outline,
                            title: 'Follower',
                            value: NumberFormat.decimalPattern()
                                .format(insights.followerCount),
                          ),
                          _MetricCard(
                            icon: Icons.trending_up,
                            title: 'Reichweite',
                            value: NumberFormat.decimalPattern()
                                .format(insights.reach),
                          ),
                          _MetricCard(
                            icon: Icons.visibility_outlined,
                            title: 'Aufrufe',
                            value: NumberFormat.decimalPattern()
                                .format(insights.impressions),
                          ),
                          _MetricCard(
                            icon: Icons.trending_up,
                            title: 'Engagement-Rate',
                            value:
                                '${insights.engagementRate.toStringAsFixed(2)}%',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Top-Beiträge',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (insights.topPosts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Meta hat keine Beiträge zurückgegeben.'),
                      ),
                    )
                  else
                    for (final post in insights.topPosts) _PostCard(post: post),
                  if (insights.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Aktualisiert: ${DateFormat('dd.MM.yyyy HH:mm').format(insights.updatedAt!.toLocal())}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final InstagramPost post;

  @override
  Widget build(BuildContext context) {
    final date = post.timestamp == null
        ? 'Beitrag'
        : DateFormat('dd.MM.yyyy').format(post.timestamp!.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.photo_camera_back_outlined),
        ),
        title: Text(
          post.caption.isEmpty ? post.mediaType : post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$date · ${NumberFormat.decimalPattern().format(post.likeCount)} Likes · ${NumberFormat.decimalPattern().format(post.commentsCount)} Kommentare',
        ),
      ),
    );
  }
}
