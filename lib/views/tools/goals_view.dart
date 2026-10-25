import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/workspace.dart';
import '../../services/supabase_service.dart';

class GoalsView extends StatefulWidget {
  const GoalsView({super.key});

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  final _service = SupabaseService.fromInitialized();
  List<CreatorGoal> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _goals = await _service.getGoals();
    } catch (error) {
      _error = 'Ziele konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([CreatorGoal? goal]) async {
    final result = await showDialog<CreatorGoal>(
      context: context,
      builder: (_) => _GoalDialog(goal: goal),
    );
    if (result == null) {
      return;
    }
    try {
      await _service.saveGoal(result);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Ziel konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _toggle(CreatorGoal goal, bool completed) async {
    try {
      await _service.saveGoal(
        CreatorGoal(
          id: goal.id,
          title: goal.title,
          description: goal.description,
          dueAt: goal.dueAt,
          completedAt: completed ? DateTime.now() : null,
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Fortschritt konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _delete(CreatorGoal goal) async {
    if (goal.id == null) {
      return;
    }
    try {
      await _service.deleteGoal(goal.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Ziel konnte nicht gelöscht werden: $error');
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = _goals.where((goal) => goal.isCompleted).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ziele & Meilensteine')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Ziel hinzufügen'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$completed von ${_goals.length} Meilensteinen erreicht',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: _goals.isEmpty
                                    ? 0
                                    : completed / _goals.length,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_goals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Lege ein Ziel an und halte deine Erfolge fest.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        for (final goal in _goals)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Checkbox(
                                value: goal.isCompleted,
                                onChanged: (value) =>
                                    _toggle(goal, value ?? false),
                              ),
                              title: Text(
                                goal.title,
                                style: goal.isCompleted
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                      )
                                    : null,
                              ),
                              subtitle: Text(
                                [
                                  if (goal.description.isNotEmpty)
                                    goal.description,
                                  if (goal.dueAt != null)
                                    'Zieldatum: ${DateFormat('dd.MM.yyyy').format(goal.dueAt!)}',
                                  if (goal.completedAt != null)
                                    'Erreicht am ${DateFormat('dd.MM.yyyy').format(goal.completedAt!)}',
                                ].join(' · '),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(goal);
                                  } else {
                                    _delete(goal);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Bearbeiten'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Löschen'),
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
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.goal});

  final CreatorGoal? goal;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal?.title ?? '');
    _description = TextEditingController(text: widget.goal?.description ?? '');
    _dueAt = widget.goal?.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _dueAt = date);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.goal == null ? 'Neues Ziel' : 'Ziel bearbeiten'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Meilenstein'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte gib einen Meilenstein ein.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Beschreibung / Erfolg'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dueAt == null
                            ? 'Kein Zieldatum'
                            : DateFormat('dd.MM.yyyy').format(_dueAt!),
                      ),
                    ),
                    IconButton(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                    if (_dueAt != null)
                      IconButton(
                        tooltip: 'Datum entfernen',
                        onPressed: () => setState(() => _dueAt = null),
                        icon: const Icon(Icons.clear),
                      ),
                  ],
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
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) {
                return;
              }
              Navigator.pop(
                context,
                CreatorGoal(
                  id: widget.goal?.id,
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  dueAt: _dueAt,
                  completedAt: widget.goal?.completedAt,
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      );
}
