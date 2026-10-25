import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/project.dart';
import '../../services/supabase_service.dart';

class PipelineView extends StatefulWidget {
  const PipelineView({super.key});

  @override
  State<PipelineView> createState() => _PipelineViewState();
}

class _PipelineViewState extends State<PipelineView> {
  static const _statuses = ['Offen', 'In Arbeit', 'Abgeschlossen'];
  final _service = SupabaseService.fromInitialized();
  List<Customer> _customers = [];
  List<Project> _projects = [];
  String _statusFilter = 'Alle';
  bool _staleInProgressOnly = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _customers = await _service.getCustomers();
      _projects = await _service.getProjects();
    } catch (error) {
      _error = 'Pipeline konnte nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createProject() async {
    if (_customers.isEmpty) {
      _showMessage('Lege zuerst einen Kunden an.');
      return;
    }
    final project = await showDialog<Project>(
      context: context,
      builder: (_) => _NewProjectDialog(customers: _customers),
    );
    if (project == null) {
      return;
    }
    try {
      await _service.createProject(project);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Projekt konnte nicht erstellt werden: $error');
      }
    }
  }

  Future<void> _changeStatus(Project project, String status) async {
    try {
      await _service.updateProject(
        Project(
          id: project.id,
          kundeId: project.kundeId,
          titel: project.titel,
          projektTyp: project.projektTyp,
          status: status,
          shotlistDaten: project.shotlistDaten,
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Projektstatus konnte nicht geändert werden: $error');
      }
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projekt löschen?'),
        content: Text('„${project.titel}“ wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || project.id == null) {
      return;
    }
    try {
      await _service.deleteProject(project.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Projekt konnte nicht gelöscht werden: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _typeIcon(ProjectType type) => switch (type) {
        ProjectType.foto => Icons.camera_alt_outlined,
        ProjectType.video => Icons.videocam_outlined,
        ProjectType.gespraech => Icons.mic_none_outlined,
        ProjectType.kombi => Icons.auto_awesome_mosaic_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('Projekt'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _PipelineError(message: _error!, onRetry: _load)
              : _customers.isEmpty
                  ? const Center(
                      child: Text(
                          'Lege zuerst einen Kunden an, um Projekte zu planen.'),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 48) / 3;
                        final columnWidth =
                            width.clamp(270.0, 380.0).toDouble();
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  SizedBox(
                                    width: constraints.maxWidth < 430
                                        ? constraints.maxWidth - 32
                                        : 220,
                                    child: DropdownButtonFormField<String>(
                                      value: _statusFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Statusfilter',
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'Alle',
                                          child: Text('Alle Status'),
                                        ),
                                        for (final status in _statuses)
                                          DropdownMenuItem(
                                            value: status,
                                            child: Text(status),
                                          ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _statusFilter = value);
                                        }
                                      },
                                    ),
                                  ),
                                  FilterChip(
                                    selected: _staleInProgressOnly,
                                    avatar: const Icon(Icons.schedule),
                                    label: const Text(
                                      'In Arbeit > 14 Tage',
                                    ),
                                    onSelected: (selected) => setState(
                                      () => _staleInProgressOnly = selected,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var index = 0;
                                        index < _statuses.length;
                                        index++) ...[
                                      if (index > 0) const SizedBox(width: 14),
                                      SizedBox(
                                        width: columnWidth,
                                        child: _buildColumn(_statuses[index]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
    );
  }

  Widget _buildColumn(String status) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final projects = _projects.where((project) {
      if (project.status != status) {
        return false;
      }
      if (_statusFilter != 'Alle' && project.status != _statusFilter) {
        return false;
      }
      if (_staleInProgressOnly) {
        final changedAt = project.statusUpdatedAt;
        if (project.status != 'In Arbeit' ||
            changedAt == null ||
            !changedAt.isBefore(cutoff)) {
          return false;
        }
      }
      return true;
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text('${projects.length}')),
                ],
              ),
            ),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Keine Projekte'),
              )
            else
              for (final project in projects)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_typeIcon(project.projektTyp), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project.titel,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Status ändern',
                              onSelected: (value) =>
                                  _changeStatus(project, value),
                              itemBuilder: (context) => [
                                for (final value in _statuses)
                                  PopupMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                              ],
                              icon: const Icon(Icons.more_vert),
                            ),
                          ],
                        ),
                        Text(
                          _customerName(project.kundeId),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${project.projektTyp.label} · ${project.shotlistDaten.length} Szenen',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _deleteProject(project),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Löschen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _customerName(String customerId) {
    for (final customer in _customers) {
      if (customer.id == customerId) {
        return customer.name;
      }
    }
    return 'Kunde';
  }
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({required this.customers});

  final List<Customer> customers;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  late String _customerId;
  ProjectType _type = ProjectType.foto;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customers.first.id!;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      Project(
        kundeId: _customerId,
        titel: _titleController.text.trim(),
        projektTyp: _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersWithIds =
        widget.customers.where((customer) => customer.id != null).toList();
    return AlertDialog(
      title: const Text('Neues Projekt'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Projekttitel'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Bitte gib einen Titel ein.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _customerId,
                decoration: const InputDecoration(labelText: 'Kunde'),
                items: [
                  for (final customer in customersWithIds)
                    DropdownMenuItem(
                      value: customer.id!,
                      child: Text(customer.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _customerId = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProjectType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Projekttyp'),
                items: [
                  for (final type in ProjectType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Erstellen')),
      ],
    );
  }
}

class _PipelineError extends StatelessWidget {
  const _PipelineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(message, textAlign: TextAlign.center),
          ),
          OutlinedButton(onPressed: onRetry, child: const Text('Erneut laden')),
        ],
      ),
    );
  }
}
