import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/workspace.dart';
import '../../services/supabase_service.dart';

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final _service = SupabaseService.fromInitialized();
  List<DashboardTask> _tasks = [];
  bool _loading = true;
  String? _error;
  TaskStatus? _filter;

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
      _tasks = await _service.getTasks();
    } catch (error) {
      _error = 'Aufgaben konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([DashboardTask? task]) async {
    final edited = await showDialog<DashboardTask>(
      context: context,
      builder: (_) => _TaskDialog(task: task),
    );
    if (edited == null) {
      return;
    }
    try {
      await _service.saveTask(edited);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Aufgabe konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _setStatus(DashboardTask task, TaskStatus status) async {
    try {
      await _service.saveTask(
        DashboardTask(
          id: task.id,
          title: task.title,
          description: task.description,
          status: status,
          priority: task.priority,
          dueAt: task.dueAt,
          completedAt:
              status == TaskStatus.done ? DateTime.now() : task.completedAt,
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Status konnte nicht aktualisiert werden: $error');
      }
    }
  }

  Future<void> _delete(DashboardTask task) async {
    if (task.id == null) {
      return;
    }
    try {
      await _service.deleteTask(task.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Aufgabe konnte nicht gelöscht werden: $error');
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
    final tasks = _tasks
        .where((task) => _filter == null || task.status == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgaben'),
        actions: [
          PopupMenuButton<TaskStatus?>(
            tooltip: 'Status filtern',
            initialValue: _filter,
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Alle Status')),
              PopupMenuItem(value: TaskStatus.open, child: Text('Offen')),
              PopupMenuItem(
                value: TaskStatus.inProgress,
                child: Text('In Bearbeitung'),
              ),
              PopupMenuItem(value: TaskStatus.done, child: Text('Erledigt')),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Aufgabe'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _LoadError(message: _error!, retry: _load)
              : tasks.isEmpty
                  ? const Center(
                      child: Text('Keine Aufgaben für diesen Filter.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Card(
                            child: ListTile(
                              leading: Checkbox(
                                value: task.status == TaskStatus.done,
                                onChanged: (value) => _setStatus(
                                  task,
                                  value == true
                                      ? TaskStatus.done
                                      : TaskStatus.open,
                                ),
                              ),
                              title: Text(
                                task.title,
                                style: task.status == TaskStatus.done
                                    ? const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                      )
                                    : null,
                              ),
                              subtitle: Text(
                                [
                                  _statusName(task.status),
                                  if (task.dueAt != null)
                                    DateFormat('dd.MM.yyyy HH:mm')
                                        .format(task.dueAt!),
                                  'Priorität: ${_priorityName(task.priority)}',
                                ].join(' · '),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(task);
                                  } else if (value == 'delete') {
                                    _delete(task);
                                  } else {
                                    _setStatus(
                                      task,
                                      TaskStatus.values.byName(value),
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'inProgress',
                                    child: Text('In Bearbeitung'),
                                  ),
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Text('Wieder öffnen'),
                                  ),
                                  PopupMenuDivider(),
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
                          );
                        },
                      ),
                    ),
    );
  }

  String _statusName(TaskStatus status) => switch (status) {
        TaskStatus.open => 'Offen',
        TaskStatus.inProgress => 'In Bearbeitung',
        TaskStatus.done => 'Erledigt',
      };

  String _priorityName(TaskPriority priority) => switch (priority) {
        TaskPriority.low => 'Niedrig',
        TaskPriority.normal => 'Normal',
        TaskPriority.high => 'Hoch',
      };
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.task});

  final DashboardTask? task;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late TaskStatus _status;
  late TaskPriority _priority;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _description = TextEditingController(text: widget.task?.description ?? '');
    _status = widget.task?.status ?? TaskStatus.open;
    _priority = widget.task?.priority ?? TaskPriority.normal;
    _dueAt = widget.task?.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? TimeOfDay.fromDateTime(now)
          : TimeOfDay.fromDateTime(_dueAt!),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.task == null ? 'Aufgabe hinzufügen' : 'Aufgabe ändern'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _title,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Bitte gib einen Titel ein.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Beschreibung'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: TaskStatus.open,
                        child: Text('Offen'),
                      ),
                      DropdownMenuItem(
                        value: TaskStatus.inProgress,
                        child: Text('In Bearbeitung'),
                      ),
                      DropdownMenuItem(
                        value: TaskStatus.done,
                        child: Text('Erledigt'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priorität'),
                    items: const [
                      DropdownMenuItem(
                        value: TaskPriority.low,
                        child: Text('Niedrig'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.normal,
                        child: Text('Normal'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.high,
                        child: Text('Hoch'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _priority = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dueAt == null
                              ? 'Kein Fälligkeitsdatum'
                              : DateFormat('dd.MM.yyyy HH:mm').format(_dueAt!),
                        ),
                      ),
                      IconButton(
                        onPressed: _pickDueDate,
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
                DashboardTask(
                  id: widget.task?.id,
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  status: _status,
                  priority: _priority,
                  dueAt: _dueAt,
                  completedAt: widget.task?.completedAt,
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('Erneut laden')),
          ],
        ),
      );
}
