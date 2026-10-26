import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/workspace.dart';
import '../../models/project.dart';
import '../../models/shotlist.dart';
import '../../services/pdf_export_service.dart';
import '../../services/supabase_service.dart';

class ShotlistView extends StatefulWidget {
  const ShotlistView({super.key, this.initialProjectId});

  final String? initialProjectId;

  @override
  State<ShotlistView> createState() => _ShotlistViewState();
}

class _ShotlistViewState extends State<ShotlistView> {
  final _service = SupabaseService.fromInitialized();
  List<Project> _projects = [];
  List<EquipmentItem> _equipment = [];
  String? _selectedProjectId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  Project? get _selectedProject {
    for (final project in _projects) {
      if (project.id == _selectedProjectId) {
        return project;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getProjects(),
        _service.getEquipment(),
      ]);
      _projects = results[0] as List<Project>;
      _equipment = results[1] as List<EquipmentItem>;
      if (!_projects.any((project) => project.id == _selectedProjectId)) {
        _selectedProjectId = _projects.isEmpty ? null : _projects.first.id;
      }
    } catch (error) {
      _error = 'Shotlists konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editScene([Shotlist? original]) async {
    final edited = await showDialog<Shotlist>(
      context: context,
      builder: (_) => _ShotEditorDialog(
        equipment: _equipment,
        shot: original ??
            Shotlist(
              szeneNummer: (_selectedProject?.shotlistDaten.length ?? 0) + 1,
            ),
      ),
    );
    if (edited == null) {
      return;
    }
    final entries = [...?_selectedProject?.shotlistDaten];
    if (original == null) {
      entries.add(edited);
    } else {
      final index = entries.indexOf(original);
      if (index >= 0) {
        entries[index] = edited;
      }
    }
    await _save(entries);
  }

  Future<void> _toggleComplete(Shotlist shot, bool completed) async {
    final entries = [
      for (final item in _selectedProject!.shotlistDaten)
        if (item == shot)
          Shotlist(
            szeneNummer: item.szeneNummer,
            einstellungsGroesse: item.einstellungsGroesse,
            kameraBewegung: item.kameraBewegung,
            beschreibung: item.beschreibung,
            audioSfx: item.audioSfx,
            istErledigt: completed,
            equipmentIds: item.equipmentIds,
          )
        else
          item,
    ];
    await _save(entries);
  }

  Future<void> _exportPdf() async {
    final project = _selectedProject;
    if (project == null) {
      return;
    }
    try {
      final bytes = await PdfExportService.shotlist(
        project: project,
        shots: project.shotlistDaten,
        equipment: _equipment,
      );
      final filename =
          'shotlist-${project.titel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF konnte nicht erstellt werden: $error')),
        );
      }
    }
  }

  String _equipmentNames(Shotlist shot) => _equipment
      .where(
        (item) => item.id != null && shot.equipmentIds.contains(item.id),
      )
      .map((item) => item.name)
      .join(', ');

  Future<void> _deleteScene(Shotlist shot) async {
    final entries =
        _selectedProject!.shotlistDaten.where((item) => item != shot).toList();
    await _save(entries);
  }

  Future<void> _save(List<Shotlist> entries) async {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updated = await _service.saveManualShotlist(
        projectId: projectId,
        shotlist: entries,
      );
      _projects = [
        for (final project in _projects)
          if (project.id == projectId) updated else project,
      ];
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Shotlist konnte nicht gespeichert werden: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuelle Shotlist'),
        actions: [
          if (project != null)
            IconButton(
              tooltip: 'Shotlist als PDF exportieren',
              onPressed: _isSaving ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Neu laden',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: project == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => _editScene(),
              icon: const Icon(Icons.add),
              label: const Text('Szene manuell hinzufügen'),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ShotlistError(message: _error!, onRetry: _load)
              : _projects.isEmpty
                  ? const Center(
                      child:
                          Text('Erstelle zuerst ein Projekt in der Pipeline.'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedProjectId,
                            decoration:
                                const InputDecoration(labelText: 'Projekt'),
                            items: [
                              for (final item in _projects)
                                DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.titel),
                                ),
                            ],
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(
                                      () => _selectedProjectId = value,
                                    ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'Alle Szenen werden von dir am Set eingetragen und bearbeitet.',
                          ),
                        ),
                        Expanded(
                          child: project!.shotlistDaten.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Noch keine Szenen. Füge deine erste Szene manuell hinzu.',
                                  ),
                                )
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    100,
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Szene')),
                                        DataColumn(label: Text('Einstellung')),
                                        DataColumn(
                                            label: Text('Kamerabewegung')),
                                        DataColumn(label: Text('Beschreibung')),
                                        DataColumn(label: Text('Audio/SFX')),
                                        DataColumn(label: Text('Equipment')),
                                        DataColumn(label: Text('Erledigt')),
                                        DataColumn(label: Text('Aktionen')),
                                      ],
                                      rows: [
                                        for (final shot
                                            in project.shotlistDaten)
                                          DataRow(
                                            cells: [
                                              DataCell(
                                                  Text('${shot.szeneNummer}')),
                                              DataCell(
                                                Text(shot.einstellungsGroesse),
                                                onTap: () => _editScene(shot),
                                              ),
                                              DataCell(
                                                Text(shot.kameraBewegung),
                                                onTap: () => _editScene(shot),
                                              ),
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxWidth: 240,
                                                  ),
                                                  child: Text(
                                                    shot.beschreibung,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                onTap: () => _editScene(shot),
                                              ),
                                              DataCell(
                                                Text(shot.audioSfx),
                                                onTap: () => _editScene(shot),
                                              ),
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxWidth: 180,
                                                  ),
                                                  child: Text(
                                                    _equipmentNames(shot),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Checkbox(
                                                  value: shot.istErledigt,
                                                  onChanged: _isSaving
                                                      ? null
                                                      : (value) =>
                                                          _toggleComplete(
                                                            shot,
                                                            value ?? false,
                                                          ),
                                                ),
                                              ),
                                              DataCell(
                                                Wrap(
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Bearbeiten',
                                                      onPressed: _isSaving
                                                          ? null
                                                          : () =>
                                                              _editScene(shot),
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Löschen',
                                                      onPressed: _isSaving
                                                          ? null
                                                          : () => _deleteScene(
                                                              shot),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }
}

class _ShotEditorDialog extends StatefulWidget {
  const _ShotEditorDialog({
    required this.shot,
    required this.equipment,
  });

  final Shotlist shot;
  final List<EquipmentItem> equipment;

  @override
  State<_ShotEditorDialog> createState() => _ShotEditorDialogState();
}

class _ShotEditorDialogState extends State<_ShotEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _size;
  late final TextEditingController _movement;
  late final TextEditingController _description;
  late final TextEditingController _audio;
  late Set<String> _equipmentIds;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: '${widget.shot.szeneNummer}');
    _size = TextEditingController(text: widget.shot.einstellungsGroesse);
    _movement = TextEditingController(text: widget.shot.kameraBewegung);
    _description = TextEditingController(text: widget.shot.beschreibung);
    _audio = TextEditingController(text: widget.shot.audioSfx);
    _equipmentIds = widget.shot.equipmentIds.toSet();
  }

  @override
  void dispose() {
    _number.dispose();
    _size.dispose();
    _movement.dispose();
    _description.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      Shotlist(
        szeneNummer: int.parse(_number.text),
        einstellungsGroesse: _size.text.trim(),
        kameraBewegung: _movement.text.trim(),
        beschreibung: _description.text.trim(),
        audioSfx: _audio.text.trim(),
        istErledigt: widget.shot.istErledigt,
        equipmentIds: _equipmentIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Szene ${widget.shot.szeneNummer} bearbeiten'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Szenennummer'),
                  validator: (value) {
                    if (int.tryParse(value ?? '') == null ||
                        int.parse(value!) < 1) {
                      return 'Bitte gib eine positive Nummer ein.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _size,
                  decoration:
                      const InputDecoration(labelText: 'Einstellungsgröße'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _movement,
                  decoration:
                      const InputDecoration(labelText: 'Kamerabewegung'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Beschreibung'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _audio,
                  decoration: const InputDecoration(labelText: 'Audio / SFX'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Equipment',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (widget.equipment.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Lege Equipment zuerst in den Einstellungen an.',
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final item in widget.equipment)
                        FilterChip(
                          label: Text(item.name),
                          selected: _equipmentIds.contains(item.id),
                          onSelected: item.id == null
                              ? null
                              : (selected) => setState(() {
                                    if (selected) {
                                      _equipmentIds.add(item.id!);
                                    } else {
                                      _equipmentIds.remove(item.id);
                                    }
                                  }),
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
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

class _ShotlistError extends StatelessWidget {
  const _ShotlistError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(message, textAlign: TextAlign.center),
            ),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Erneut laden')),
          ],
        ),
      );
}
