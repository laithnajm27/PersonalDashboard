import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/calendar.dart';
import '../../services/csv_helper.dart';
import '../../services/supabase_service.dart';
import 'calendar_help_view.dart';

enum _CalendarDisplay { month, week, day }

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  final _service = SupabaseService.fromInitialized();
  List<CalendarEntry> _entries = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  _CalendarDisplay _display = _CalendarDisplay.month;
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
      _entries = await _service.getCalendarEntries();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Kalender konnte nicht geladen werden: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editEntry([CalendarEntry? entry]) async {
    final edited = await showDialog<CalendarEntry>(
      context: context,
      builder: (_) => _CalendarEntryDialog(entry: entry),
    );
    if (edited == null) {
      return;
    }
    try {
      if (entry == null) {
        await _service.createCalendarEntry(edited);
      } else {
        await _service.updateCalendarEntry(edited);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Eintrag konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _toggleDone(CalendarEntry entry, bool value) async {
    try {
      await _service.updateCalendarEntry(
        CalendarEntry(
          id: entry.id,
          typ: entry.typ,
          titel: entry.titel,
          dateTime: entry.dateTime,
          erledigt: value,
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Status konnte nicht geändert werden: $error');
      }
    }
  }

  Future<void> _deleteEntry(CalendarEntry entry) async {
    if (entry.id == null) {
      return;
    }
    try {
      await _service.deleteCalendarEntry(entry.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Eintrag konnte nicht gelöscht werden: $error');
      }
    }
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw const FormatException(
            'Die CSV-Datei konnte nicht gelesen werden.');
      }
      final entries = CsvHelper.importCalendar(utf8.decode(bytes));
      for (final entry in entries) {
        await _service.createCalendarEntry(entry);
      }
      await _load();
      if (mounted) {
        _showMessage('${entries.length} Kalender-Einträge importiert.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('CSV-Import fehlgeschlagen: $error');
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final contents = CsvHelper.exportCalendar(_entries);
      await FilePicker.platform.saveFile(
        fileName: 'personal-dashboard-kalender.csv',
        bytes: Uint8List.fromList(utf8.encode(contents)),
      );
    } catch (error) {
      if (mounted) {
        _showMessage('CSV-Export fehlgeschlagen: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<CalendarEntry> _entriesOn(DateTime day) =>
      _entries.where((entry) => isSameDay(entry.dateTime, day)).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  void _selectDisplay(_CalendarDisplay display) {
    setState(() => _display = display);
  }

  Widget _buildCalendar() {
    if (_display == _CalendarDisplay.day) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Vorheriger Tag',
              onPressed: () => setState(() {
                _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                _focusedDay = _selectedDay;
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(_selectedDay),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Nächster Tag',
              onPressed: () => setState(() {
                _selectedDay = _selectedDay.add(const Duration(days: 1));
                _focusedDay = _selectedDay;
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
    }

    return TableCalendar<CalendarEntry>(
      locale: 'de_DE',
      firstDay: DateTime(2000),
      lastDay: DateTime(2100),
      focusedDay: _focusedDay,
      calendarFormat: _display == _CalendarDisplay.month
          ? CalendarFormat.month
          : CalendarFormat.week,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Monat',
        CalendarFormat.week: 'Woche',
      },
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _entriesOn,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
      calendarStyle: CalendarStyle(
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildSelectedDayEntries() {
    final entries = _entriesOn(_selectedDay);
    final dateFormat = DateFormat('HH:mm');
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.event_available_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Keine Einträge für diesen Tag.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: ListTile(
            leading: Checkbox(
              value: entry.erledigt,
              onChanged: (value) => _toggleDone(entry, value ?? false),
            ),
            title: Text(
              entry.titel,
              style: entry.erledigt
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              '${entry.typ == CalendarEntryType.task ? 'Aufgabe' : 'Termin'} · ${dateFormat.format(entry.dateTime)}',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Bearbeiten',
                  onPressed: () => _editEntry(entry),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Löschen',
                  onPressed: () => _deleteEntry(entry),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          IconButton(
            tooltip: 'CSV importieren',
            onPressed: _importCsv,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: 'CSV exportieren',
            onPressed: _exportCsv,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'So geht’s',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CalendarHelpView(),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEntry(),
        icon: const Icon(Icons.add),
        label: const Text('Eintrag'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: SegmentedButton<_CalendarDisplay>(
                        segments: const [
                          ButtonSegment(
                            value: _CalendarDisplay.month,
                            label: Text('Monat'),
                            icon: Icon(Icons.calendar_view_month),
                          ),
                          ButtonSegment(
                            value: _CalendarDisplay.week,
                            label: Text('Woche'),
                            icon: Icon(Icons.calendar_view_week),
                          ),
                          ButtonSegment(
                            value: _CalendarDisplay.day,
                            label: Text('Tag'),
                            icon: Icon(Icons.calendar_view_day),
                          ),
                        ],
                        selected: {_display},
                        onSelectionChanged: (selected) =>
                            _selectDisplay(selected.first),
                      ),
                    ),
                    _buildCalendar(),
                    const Divider(height: 1),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _buildSelectedDayEntries(),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CalendarEntryDialog extends StatefulWidget {
  const _CalendarEntryDialog({this.entry});

  final CalendarEntry? entry;

  @override
  State<_CalendarEntryDialog> createState() => _CalendarEntryDialogState();
}

class _CalendarEntryDialogState extends State<_CalendarEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late CalendarEntryType _type;
  late DateTime _dateTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.titel ?? '');
    _type = widget.entry?.typ ?? CalendarEntryType.event;
    _dateTime = widget.entry?.dateTime ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _dateTime.hour,
          _dateTime.minute,
        );
      });
    }
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time != null) {
      setState(() {
        _dateTime = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      CalendarEntry(
        id: widget.entry?.id,
        typ: _type,
        titel: _titleController.text.trim(),
        dateTime: _dateTime,
        erledigt: widget.entry?.erledigt ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd.MM.yyyy · HH:mm');
    return AlertDialog(
      title:
          Text(widget.entry == null ? 'Neuer Eintrag' : 'Eintrag bearbeiten'),
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
                decoration: const InputDecoration(labelText: 'Titel'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Bitte gib einen Titel ein.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CalendarEntryType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Typ'),
                items: const [
                  DropdownMenuItem(
                    value: CalendarEntryType.task,
                    child: Text('Aufgabe'),
                  ),
                  DropdownMenuItem(
                    value: CalendarEntryType.event,
                    child: Text('Termin'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(format.format(_dateTime))),
                  IconButton(
                    tooltip: 'Datum auswählen',
                    onPressed: _chooseDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                  IconButton(
                    tooltip: 'Uhrzeit auswählen',
                    onPressed: _chooseTime,
                    icon: const Icon(Icons.schedule),
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
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}
