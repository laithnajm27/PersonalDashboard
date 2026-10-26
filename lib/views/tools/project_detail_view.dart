import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/project.dart';
import '../../models/workspace.dart';
import '../../services/project_gallery_service.dart';
import '../../services/supabase_service.dart';
import 'shotlist_view.dart';

class ProjectDetailView extends StatefulWidget {
  const ProjectDetailView({
    super.key,
    required this.project,
    required this.customerName,
  });

  final Project project;
  final String customerName;

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  final _service = SupabaseService.fromInitialized();
  final _galleryService = ProjectGalleryService.fromInitialized();
  final _dateFormat = DateFormat('dd.MM.yyyy');
  late Project _project = widget.project;
  List<ProjectLink> _links = [];
  List<DashboardTask> _tasks = [];
  ProjectGallery? _gallery;
  List<ProjectGalleryMedia> _galleryMedia = [];
  Map<String, String> _mediaUrls = {};
  String? _shareUrl;
  bool _loading = true;
  bool _uploadingMedia = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projectId = _project.id;
    if (projectId == null) {
      setState(() {
        _loading = false;
        _error = 'Dieses Projekt hat keine gültige ID.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getProjectLinks(projectId),
        _service.getTasks(projectId: projectId),
        _galleryService.getGallery(projectId),
      ]);
      _links = results[0] as List<ProjectLink>;
      _tasks = results[1] as List<DashboardTask>;
      _gallery = results[2] as ProjectGallery?;
      final galleryId = _gallery?.id;
      if (galleryId == null) {
        _galleryMedia = [];
        _mediaUrls = {};
      } else {
        _galleryMedia = await _galleryService.getMedia(galleryId);
        _mediaUrls = await _galleryService.createSignedUrls(_galleryMedia);
      }
    } catch (error) {
      _error = 'Projektinformationen konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editProject() async {
    final edited = await showDialog<Project>(
      context: context,
      builder: (_) => _ProjectEditorDialog(project: _project),
    );
    if (edited == null) {
      return;
    }
    try {
      _project = await _service.updateProject(edited);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Projekt konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _addLink([ProjectLink? link]) async {
    final edited = await showDialog<ProjectLink>(
      context: context,
      builder: (_) => _ProjectLinkDialog(
        projectId: _project.id!,
        link: link,
      ),
    );
    if (edited == null) {
      return;
    }
    try {
      await _service.saveProjectLink(edited);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Link konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _deleteLink(ProjectLink link) async {
    if (link.id == null) {
      return;
    }
    try {
      await _service.deleteProjectLink(link.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Link konnte nicht gelöscht werden: $error');
      }
    }
  }

  Future<void> _openLink(ProjectLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      _message('Dieser Link ist ungültig.');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _message('Der Link konnte nicht geöffnet werden.');
      }
    } catch (error) {
      if (mounted) {
        _message('Link konnte nicht geöffnet werden: $error');
      }
    }
  }

  Future<void> _addTask() async {
    final task = await showDialog<DashboardTask>(
      context: context,
      builder: (_) => _ProjectTaskDialog(projectId: _project.id!),
    );
    if (task == null) {
      return;
    }
    try {
      await _service.saveTask(task);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Aufgabe konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _editGallery() async {
    final edited = await showDialog<ProjectGallery>(
      context: context,
      builder: (_) => _ProjectGalleryDialog(
        project: _project,
        gallery: _gallery,
      ),
    );
    if (edited == null) {
      return;
    }
    try {
      await _galleryService.saveGallery(edited);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Galerie konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _uploadGalleryMedia() async {
    final gallery = _gallery;
    if (gallery == null) {
      _message('Richte zuerst die Galerie ein.');
      return;
    }
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: true,
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) {
        return;
      }
      setState(() => _uploadingMedia = true);
      final uploaded = await _galleryService.uploadFiles(
        gallery: gallery,
        files: selection.files,
      );
      await _load();
      if (mounted) {
        _message('${uploaded.length} Medien zur Galerie hinzugefügt.');
      }
    } catch (error) {
      if (mounted) {
        _message('Medien konnten nicht hochgeladen werden: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingMedia = false);
      }
    }
  }

  Future<void> _deleteGalleryMedia(ProjectGalleryMedia media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Medium entfernen?'),
        content: Text('„${media.title}“ wird aus der Kundengalerie entfernt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _galleryService.deleteMedia(media);
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Medium konnte nicht vollständig entfernt werden: $error');
      }
    }
  }

  Future<void> _createShareLink() async {
    final gallery = _gallery;
    if (gallery == null || gallery.id == null) {
      _message('Richte zuerst die Galerie ein.');
      return;
    }
    if (gallery.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Galerie-Link erneuern?'),
          content: const Text(
            'Ein neuer Link macht alle zuvor geteilten Links sofort ungültig.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link erneuern'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    try {
      final shareUrl = await _galleryService.issueShareLink(gallery);
      if (!mounted) {
        return;
      }
      setState(() => _shareUrl = shareUrl);
      await _load();
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (mounted) {
        _message('Galerie-Link erstellt und in die Zwischenablage kopiert.');
      }
    } catch (error) {
      if (mounted) {
        _message('Galerie-Link konnte nicht erstellt werden: $error');
      }
    }
  }

  Future<void> _copyShareLink() async {
    final shareUrl = _shareUrl;
    if (shareUrl == null) {
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (mounted) {
        _message('Galerie-Link kopiert.');
      }
    } catch (error) {
      if (mounted) {
        _message('Link konnte nicht kopiert werden: $error');
      }
    }
  }

  Future<void> _revokeShareLink() async {
    final gallery = _gallery;
    if (gallery == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Freigabe beenden?'),
        content: const Text('Der bisher geteilte Link wird sofort ungültig.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Freigabe beenden'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _galleryService.revokeShareLink(gallery);
      if (mounted) {
        setState(() => _shareUrl = null);
      }
      await _load();
      if (mounted) {
        _message('Der Galerie-Link wurde widerrufen.');
      }
    } catch (error) {
      if (mounted) {
        _message('Freigabe konnte nicht beendet werden: $error');
      }
    }
  }

  Future<void> _toggleTask(DashboardTask task, bool completed) async {
    try {
      await _service.saveTask(
        DashboardTask(
          id: task.id,
          title: task.title,
          description: task.description,
          status: completed ? TaskStatus.done : TaskStatus.open,
          priority: task.priority,
          dueAt: task.dueAt,
          completedAt: completed ? DateTime.now() : null,
          projectId: task.projectId,
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Aufgabenstatus konnte nicht geändert werden: $error');
      }
    }
  }

  Future<void> _deleteTask(DashboardTask task) async {
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

  String _dateRange() {
    final start = _project.startAt;
    final due = _project.dueAt;
    if (start == null && due == null) {
      return 'Noch nicht geplant';
    }
    if (start != null && due != null) {
      return '${_dateFormat.format(start)} – ${_dateFormat.format(due)}';
    }
    return start != null
        ? 'Start: ${_dateFormat.format(start)}'
        : 'Abgabe: ${_dateFormat.format(due!)}';
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks =
        _tasks.where((task) => task.status == TaskStatus.done).length;
    final budget = _project.budget;
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.titel),
        actions: [
          IconButton(
            tooltip: 'Projekt bearbeiten',
            onPressed: _editProject,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Projekt-Shotlist öffnen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShotlistView(initialProjectId: _project.id),
              ),
            ),
            icon: const Icon(Icons.checklist),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ProjectLoadError(message: _error!, retry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _ProjectOverviewCard(
                        project: _project,
                        customerName: widget.customerName,
                        dateRange: _dateRange(),
                        budgetLabel: budget == null
                            ? 'Kein Budget hinterlegt'
                            : NumberFormat.currency(
                                locale: 'de_DE',
                                symbol: '€',
                              ).format(budget),
                        completedTasks: completedTasks,
                        taskCount: _tasks.length,
                        linkCount: _links.length,
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Projektinformationen',
                        icon: Icons.notes_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(
                              icon: Icons.place_outlined,
                              label: 'Ort',
                              value: _project.ort.isEmpty
                                  ? 'Noch kein Ort eingetragen'
                                  : _project.ort,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.calendar_month_outlined,
                              label: 'Zeitraum',
                              value: _dateRange(),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.euro,
                              label: 'Budget',
                              value: budget == null
                                  ? 'Nicht festgelegt'
                                  : NumberFormat.currency(
                                      locale: 'de_DE',
                                      symbol: '€',
                                    ).format(budget),
                            ),
                            if (_project.beschreibung.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                _project.beschreibung,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _editProject,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Details bearbeiten'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Projektlinks',
                        icon: Icons.link,
                        action: IconButton(
                          tooltip: 'Link hinzufügen',
                          onPressed: () => _addLink(),
                          icon: const Icon(Icons.add_link),
                        ),
                        child: _links.isEmpty
                            ? const _EmptySection(
                                text:
                                    'Sammle hier Briefings, Referenzen, Cloud-Ordner, Verträge oder Abnahme-Links.',
                              )
                            : Column(
                                children: [
                                  for (final link in _links)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.open_in_new,
                                        size: 20,
                                      ),
                                      title: Text(link.title),
                                      subtitle: Text(
                                        link.note.isEmpty
                                            ? link.url
                                            : '${link.note}\n${link.url}',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _openLink(link),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _addLink(link);
                                          } else {
                                            _deleteLink(link);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Bearbeiten'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Entfernen'),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Kundengalerie',
                        icon: Icons.photo_library_outlined,
                        action: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Galerie-Einstellungen',
                              onPressed: _editGallery,
                              icon: const Icon(Icons.tune),
                            ),
                            IconButton(
                              tooltip: 'Bilder oder Videos hinzufügen',
                              onPressed: _gallery == null || _uploadingMedia
                                  ? null
                                  : _uploadGalleryMedia,
                              icon: _uploadingMedia
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined),
                            ),
                          ],
                        ),
                        child: _gallery == null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _EmptySection(
                                    text:
                                        'Erstelle eine gebrandete Galerie für dieses Projekt, lade Fotos und Videos hoch und teile einen privaten Kundenlink.',
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.icon(
                                      onPressed: _editGallery,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Galerie einrichten'),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _gallery!.isActive
                                            ? Icons.public
                                            : Icons.lock_outline,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _gallery!.isActive
                                              ? 'Freigabe aktiv'
                                              : 'Noch nicht freigegeben',
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _createShareLink,
                                        icon: const Icon(
                                          Icons.link,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _gallery!.isActive
                                              ? 'Link erneuern'
                                              : 'Link erstellen',
                                        ),
                                      ),
                                      if (_gallery!.isActive)
                                        IconButton(
                                          tooltip: 'Freigabe beenden',
                                          onPressed: _revokeShareLink,
                                          icon: const Icon(
                                            Icons.link_off,
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_shareUrl != null) ...[
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      _shareUrl!,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: _copyShareLink,
                                        icon: const Icon(Icons.copy, size: 18),
                                        label: const Text('Link kopieren'),
                                      ),
                                    ),
                                  ] else if (_gallery!.isActive) ...[
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'Der aktive Link wird aus Sicherheitsgründen nicht gespeichert. Erzeuge einen neuen Link, um ihn erneut zu kopieren.',
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_galleryMedia.length} Medien · ${_gallery!.title}',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                  if (_galleryMedia.isEmpty)
                                    const _EmptySection(
                                      text:
                                          'Lade JPG-, PNG-, WebP-, GIF-, MP4-, MOV- oder WebM-Dateien bis 100 MB hoch.',
                                    )
                                  else ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final media in _galleryMedia)
                                          _GalleryMediaTile(
                                            media: media,
                                            signedUrl: _mediaUrls[media.id],
                                            onDelete: () =>
                                                _deleteGalleryMedia(media),
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    _gallery!.allowDownload
                                        ? 'Die Galerie zeigt eine Download-/Speicheraktion. Geteilte Medien können grundsätzlich auch unabhängig davon gespeichert werden.'
                                        : 'Die Download-Schaltfläche ist ausgeblendet. Ein geteilter Link kann Medien jedoch nicht vor dem Speichern schützen.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Aufgaben',
                        icon: Icons.task_alt,
                        action: IconButton(
                          tooltip: 'Projektaufgabe hinzufügen',
                          onPressed: _addTask,
                          icon: const Icon(Icons.add),
                        ),
                        child: _tasks.isEmpty
                            ? const _EmptySection(
                                text:
                                    'Lege To-dos für dieses Projekt an, damit alle nächsten Schritte an einem Ort bleiben.',
                              )
                            : Column(
                                children: [
                                  for (final task in _tasks)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Checkbox(
                                        value: task.status == TaskStatus.done,
                                        onChanged: (value) => _toggleTask(
                                          task,
                                          value == true,
                                        ),
                                      ),
                                      title: Text(
                                        task.title,
                                        style: task.status == TaskStatus.done
                                            ? const TextStyle(
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              )
                                            : null,
                                      ),
                                      subtitle: Text(
                                        [
                                          switch (task.status) {
                                            TaskStatus.open => 'Offen',
                                            TaskStatus.inProgress =>
                                              'In Bearbeitung',
                                            TaskStatus.done => 'Erledigt',
                                          },
                                          if (task.dueAt != null)
                                            'Fällig ${_dateFormat.format(task.dueAt!)}',
                                        ].join(' · '),
                                      ),
                                      trailing: IconButton(
                                        tooltip: 'Aufgabe entfernen',
                                        onPressed: () => _deleteTask(task),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Shotlist',
                        icon: Icons.movie_creation_outlined,
                        action: TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ShotlistView(
                                initialProjectId: _project.id,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Öffnen'),
                        ),
                        child: _EmptySection(
                          text: _project.shotlistDaten.isEmpty
                              ? 'Noch keine Shots. Die Shotlist bleibt vollständig manuell und wird beim Öffnen bearbeitet.'
                              : '${_project.shotlistDaten.length} manuell gepflegte Shots · ${_project.shotlistDaten.where((shot) => shot.istErledigt).length} erledigt',
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ProjectOverviewCard extends StatelessWidget {
  const _ProjectOverviewCard({
    required this.project,
    required this.customerName,
    required this.dateRange,
    required this.budgetLabel,
    required this.completedTasks,
    required this.taskCount,
    required this.linkCount,
  });

  final Project project;
  final String customerName;
  final String dateRange;
  final String budgetLabel;
  final int completedTasks;
  final int taskCount;
  final int linkCount;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    avatar: const Icon(Icons.circle, size: 12),
                    label: Text(project.status),
                  ),
                  Chip(
                    avatar: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(project.projektTyp.label),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(customerName,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _SummaryValue(
                    label: 'Zeitraum',
                    value: dateRange,
                  ),
                  _SummaryValue(
                    label: 'Budget',
                    value: budgetLabel,
                  ),
                  _SummaryValue(
                    label: 'Aufgaben',
                    value: '$completedTasks von $taskCount erledigt',
                  ),
                  _SummaryValue(
                    label: 'Verknüpfte Links',
                    value: '$linkCount',
                  ),
                  _SummaryValue(
                    label: 'Manuelle Shots',
                    value: '${project.shotlistDaten.length}',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value),
              ],
            ),
          ),
        ],
      );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({required this.project});

  final Project project;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.project.titel);
  late final _description =
      TextEditingController(text: widget.project.beschreibung);
  late final _location = TextEditingController(text: widget.project.ort);
  late final _budget = TextEditingController(
    text: widget.project.budget?.toStringAsFixed(2) ?? '',
  );
  late DateTime? _startAt = widget.project.startAt;
  late DateTime? _dueAt = widget.project.dueAt;
  String? _dateError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? current) async => showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startAt != null && _dueAt != null && _dueAt!.isBefore(_startAt!)) {
      setState(() {
        _dateError = 'Das Projektende darf nicht vor dem Start liegen.';
      });
      return;
    }
    _dateError = null;
    final budgetText = _budget.text.trim().replaceAll(',', '.');
    final budget = budgetText.isEmpty ? null : double.tryParse(budgetText);
    if (budgetText.isNotEmpty &&
        (budget == null || !budget.isFinite || budget < 0)) {
      return;
    }
    Navigator.pop(
      context,
      Project(
        id: widget.project.id,
        kundeId: widget.project.kundeId,
        titel: _title.text.trim(),
        projektTyp: widget.project.projektTyp,
        status: widget.project.status,
        statusUpdatedAt: widget.project.statusUpdatedAt,
        beschreibung: _description.text.trim(),
        ort: _location.text.trim(),
        startAt: _startAt,
        dueAt: _dueAt,
        budget: budget,
        shotlistDaten: widget.project.shotlistDaten,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd.MM.yyyy');
    return AlertDialog(
      title: const Text('Projekt bearbeiten'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Projekttitel'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte gib einen Titel ein.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Briefing / Notizen',
                    hintText: 'Ziele, Stil, Absprachen, Lieferumfang ...',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(labelText: 'Ort'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budget,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Budget (optional)',
                    suffixText: '€',
                  ),
                  validator: (value) {
                    final input = value?.trim().replaceAll(',', '.') ?? '';
                    if (input.isEmpty) {
                      return null;
                    }
                    final amount = double.tryParse(input);
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Bitte gib einen gültigen Betrag ein.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                _DatePickerRow(
                  label: 'Projektstart',
                  value: _startAt == null ? null : format.format(_startAt!),
                  onPick: () async {
                    final date = await _pickDate(_startAt);
                    if (date != null) {
                      setState(() => _startAt = date);
                    }
                  },
                  onClear: _startAt == null
                      ? null
                      : () => setState(() => _startAt = null),
                ),
                _DatePickerRow(
                  label: 'Abgabe / Ende',
                  value: _dueAt == null ? null : format.format(_dueAt!),
                  onPick: () async {
                    final date = await _pickDate(_dueAt);
                    if (date != null) {
                      setState(() => _dueAt = date);
                    }
                  },
                  onClear: _dueAt == null
                      ? null
                      : () => setState(() => _dueAt = null),
                ),
                if (_dateError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              value == null ? '$label: nicht festgelegt' : '$label: $value',
            ),
          ),
          IconButton(
            tooltip: label,
            onPressed: onPick,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Datum entfernen',
              onPressed: onClear,
              icon: const Icon(Icons.clear),
            ),
        ],
      );
}

class _ProjectLinkDialog extends StatefulWidget {
  const _ProjectLinkDialog({
    required this.projectId,
    this.link,
  });

  final String projectId;
  final ProjectLink? link;

  @override
  State<_ProjectLinkDialog> createState() => _ProjectLinkDialogState();
}

class _ProjectLinkDialogState extends State<_ProjectLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.link?.title ?? '');
  late final _url = TextEditingController(text: widget.link?.url ?? '');
  late final _note = TextEditingController(text: widget.link?.note ?? '');

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final input = _url.text.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      ProjectLink(
        id: widget.link?.id,
        projectId: widget.projectId,
        title: _title.text.trim(),
        url: input,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.link == null ? 'Projektlink hinzufügen' : 'Link bearbeiten',
        ),
        content: SizedBox(
          width: 460,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'z. B. Briefing, Drive-Ordner, Referenz',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte gib dem Link einen Namen.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://...',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    return uri == null ||
                            (uri.scheme != 'https' && uri.scheme != 'http') ||
                            uri.host.isEmpty
                        ? 'Bitte gib einen gültigen http(s)-Link ein.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notiz (optional)',
                  ),
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
            onPressed: _save,
            child: const Text('Speichern'),
          ),
        ],
      );
}

class _ProjectGalleryDialog extends StatefulWidget {
  const _ProjectGalleryDialog({
    required this.project,
    this.gallery,
  });

  final Project project;
  final ProjectGallery? gallery;

  @override
  State<_ProjectGalleryDialog> createState() => _ProjectGalleryDialogState();
}

class _ProjectGalleryDialogState extends State<_ProjectGalleryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.gallery?.title ?? widget.project.titel,
  );
  late final _description = TextEditingController(
    text: widget.gallery?.description ?? '',
  );
  late bool _allowDownload = widget.gallery?.allowDownload ?? false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.gallery == null
            ? 'Kundengalerie einrichten'
            : 'Galerie-Einstellungen'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _title,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Galerietitel',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Bitte gib einen Galerietitel ein.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nachricht für den Kunden',
                      hintText: 'Persönliche Begrüßung oder kurze Hinweise',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _allowDownload,
                    onChanged: (value) =>
                        setState(() => _allowDownload = value),
                    title: const Text('Download-Schaltfläche anzeigen'),
                    subtitle: const Text(
                      'Ein privater Link kann das Speichern geteilter Medien nicht technisch verhindern.',
                    ),
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
                ProjectGallery(
                  id: widget.gallery?.id,
                  projectId: widget.project.id!,
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  allowDownload: _allowDownload,
                  isActive: widget.gallery?.isActive ?? false,
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      );
}

class _GalleryMediaTile extends StatelessWidget {
  const _GalleryMediaTile({
    required this.media,
    required this.signedUrl,
    required this.onDelete,
  });

  final ProjectGalleryMedia media;
  final String? signedUrl;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: media.isVideo
                    ? ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 42),
                        ),
                      )
                    : signedUrl == null
                        ? const Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          )
                        : Image.network(
                            signedUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aus Galerie entfernen',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 19),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ProjectTaskDialog extends StatefulWidget {
  const _ProjectTaskDialog({required this.projectId});

  final String projectId;

  @override
  State<_ProjectTaskDialog> createState() => _ProjectTaskDialogState();
}

class _ProjectTaskDialogState extends State<_ProjectTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Projektaufgabe hinzufügen'),
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
                  decoration: const InputDecoration(labelText: 'Titel'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte gib einen Titel ein.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Details'),
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
                DashboardTask(
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  projectId: widget.projectId,
                ),
              );
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      );
}

class _ProjectLoadError extends StatelessWidget {
  const _ProjectLoadError({
    required this.message,
    required this.retry,
  });

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: retry,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
}
