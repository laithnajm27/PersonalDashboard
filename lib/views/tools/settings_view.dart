import 'package:flutter/material.dart';

import '../../models/workspace.dart';
import '../../services/supabase_service.dart';
import '../../theme_mode_store.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseService.fromInitialized();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  List<EquipmentItem> _equipment = [];
  CreatorProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _smallBusinessDefault = false;
  String? _error;
  late final TabController _tabs;

  static const _profileFields = [
    ('fullName', 'Vollständiger Name'),
    ('companyName', 'Firmenname'),
    ('companyAddress', 'Anschrift'),
    ('companyEmail', 'Geschäftliche E-Mail'),
    ('companyPhone', 'Telefon'),
  ];

  static const _invoiceFields = [
    ('taxNumber', 'Steuernummer'),
    ('vatId', 'USt-IdNr. (falls vorhanden)'),
    ('bankDetails', 'Bankverbindung / IBAN'),
    ('invoiceNote', 'Standard-Zahlungs- und Rechnungshinweis'),
    ('legalNoticeUrl', 'Impressum-URL'),
    ('privacyUrl', 'Datenschutz-URL'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    for (final key in [
      ..._profileFields.map((field) => field.$1),
      ..._invoiceFields.map((field) => field.$1),
    ]) {
      _fields[key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getProfile(),
        _service.getEquipment(),
      ]);
      final profile = results[0] as CreatorProfile;
      final equipment = results[1] as List<EquipmentItem>;
      _profile = profile;
      _equipment = equipment;
      _smallBusinessDefault = profile.smallBusinessDefault;
      _fields['fullName']!.text = profile.fullName;
      _fields['companyName']!.text = profile.companyName;
      _fields['companyAddress']!.text = profile.companyAddress;
      _fields['companyEmail']!.text = profile.companyEmail;
      _fields['companyPhone']!.text = profile.companyPhone;
      _fields['taxNumber']!.text = profile.taxNumber;
      _fields['vatId']!.text = profile.vatId;
      _fields['bankDetails']!.text = profile.bankDetails;
      _fields['invoiceNote']!.text = profile.invoiceNote;
      _fields['legalNoticeUrl']!.text = profile.legalNoticeUrl;
      _fields['privacyUrl']!.text = profile.privacyUrl;
      appThemeMode.value = themeModeFromProfile(profile.themeMode);
    } catch (error) {
      _error = 'Einstellungen konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  CreatorProfile _editedProfile({String? themeMode}) {
    final profile = _profile!;
    return CreatorProfile(
      id: profile.id,
      fullName: _fields['fullName']!.text.trim(),
      companyName: _fields['companyName']!.text.trim(),
      companyAddress: _fields['companyAddress']!.text.trim(),
      companyEmail: _fields['companyEmail']!.text.trim(),
      companyPhone: _fields['companyPhone']!.text.trim(),
      taxNumber: _fields['taxNumber']!.text.trim(),
      vatId: _fields['vatId']!.text.trim(),
      bankDetails: _fields['bankDetails']!.text.trim(),
      invoiceNote: _fields['invoiceNote']!.text.trim(),
      smallBusinessDefault: _smallBusinessDefault,
      themeMode: themeMode ?? profile.themeMode,
      legalNoticeUrl: _fields['legalNoticeUrl']!.text.trim(),
      privacyUrl: _fields['privacyUrl']!.text.trim(),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      _profile = await _service.saveProfile(_editedProfile());
      if (mounted) {
        _message('Einstellungen gespeichert.');
      }
    } catch (error) {
      if (mounted) {
        _message('Einstellungen konnten nicht gespeichert werden: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    appThemeMode.value = mode;
    final profile = _profile;
    if (profile == null) {
      return;
    }
    try {
      _profile = await _service.saveProfile(
        _editedProfile(themeMode: profileThemeFromMode(mode)),
      );
    } catch (error) {
      if (mounted) {
        _message('Theme konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _editEquipment([EquipmentItem? item]) async {
    final result = await showDialog<EquipmentItem>(
      context: context,
      builder: (_) => _EquipmentDialog(item: item),
    );
    if (result == null) {
      return;
    }
    try {
      if (item == null) {
        await _service.createEquipment(result);
      } else {
        await _service.updateEquipment(result);
      }
      _equipment = await _service.getEquipment();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        _message('Equipment konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _deleteEquipment(EquipmentItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Equipment löschen?'),
        content: Text('„${item.name}“ aus deiner Liste entfernen?'),
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
    if (confirm != true || item.id == null) {
      return;
    }
    try {
      await _service.deleteEquipment(item.id!);
      _equipment = await _service.getEquipment();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        _message('Equipment konnte nicht gelöscht werden: $error');
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _fieldsFor(List<(String, String)> fields) => Column(
        children: [
          for (final field in fields) ...[
            TextFormField(
              controller: _fields[field.$1],
              decoration: InputDecoration(labelText: field.$2),
              maxLines: field.$1 == 'companyAddress' ||
                      field.$1 == 'bankDetails' ||
                      field.$1 == 'invoiceNote'
                  ? 3
                  : 1,
              validator: field.$1 == 'fullName'
                  ? (value) => value == null || value.trim().isEmpty
                      ? 'Bitte gib deinen Namen ein.'
                      : null
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Profil'),
            Tab(text: 'Equipment'),
            Tab(text: 'Rechnung'),
            Tab(text: 'Integrationen'),
          ],
        ),
      ),
      body: _isLoading
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
              : Form(
                  key: _formKey,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildProfileTab(),
                      _buildEquipmentTab(),
                      _buildInvoiceTab(),
                      _buildIntegrationsTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _settingsList(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      );

  Widget _buildProfileTab() => _settingsList([
        Text('Profil', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _fieldsFor(_profileFields),
        const SizedBox(height: 8),
        Text('Darstellung', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeMode,
          builder: (context, mode, _) => SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Hell'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dunkel'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness_outlined),
                label: Text('System'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (value) => _saveTheme(value.first),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isSaving ? null : _saveProfile,
          child: const Text('Profil speichern'),
        ),
      ]);

  Widget _buildEquipmentTab() => _settingsList([
        Row(
          children: [
            Expanded(
              child: Text(
                'Dein Equipment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editEquipment(),
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_equipment.isEmpty)
          const Text('Noch kein Equipment hinterlegt.')
        else
          for (final item in _equipment)
            Card(
              child: ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(item.name),
                subtitle:
                    item.description.isEmpty ? null : Text(item.description),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Bearbeiten',
                      onPressed: () => _editEquipment(item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Löschen',
                      onPressed: () => _deleteEquipment(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 10),
        const Text(
          'Dieses Equipment erscheint als Auswahl in deiner manuellen Shotlist.',
        ),
      ]);

  Widget _buildInvoiceTab() => _settingsList([
        Text(
          'Absenderdaten für Rechnungen und Quittungen',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Diese Angaben werden als Vorschlag verwendet. Leere Felder kannst du beim Erstellen eines Belegs ergänzen.',
        ),
        const SizedBox(height: 16),
        _fieldsFor([
          ('companyName', 'Firmenname / Name'),
          ('companyAddress', 'Vollständige Geschäftsanschrift'),
          ('companyEmail', 'E-Mail'),
          ('companyPhone', 'Telefon'),
          ..._invoiceFields.where(
            (field) => !{'legalNoticeUrl', 'privacyUrl'}.contains(field.$1),
          ),
        ]),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('§ 19 UStG standardmäßig anwenden'),
          subtitle: const Text(
            'Die Auswahl kann bei jedem Beleg erneut geändert werden.',
          ),
          value: _smallBusinessDefault,
          onChanged: (value) => setState(() => _smallBusinessDefault = value),
        ),
        _fieldsFor([
          ('legalNoticeUrl', 'Impressum-URL'),
          ('privacyUrl', 'Datenschutzerklärung-URL'),
        ]),
        FilledButton(
          onPressed: _isSaving ? null : _saveProfile,
          child: const Text('Rechnungsdaten speichern'),
        ),
      ]);

  Widget _buildIntegrationsTab() => _settingsList([
        Text(
          'Integrationen',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.camera_alt_outlined),
            title: Text('Instagram Business Login'),
            subtitle: Text(
              'Dein Konto wird einzeln mit deinem Dashboard-Benutzer verbunden. Die Verbindung und Zugriffstoken werden serverseitig verwaltet.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.auto_awesome_outlined),
            title: Text('KI-Assistent'),
            subtitle: Text(
              'Groq wird über eine Supabase Edge Function verwendet. API-Schlüssel bleiben serverseitig.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Meta-App-Plattform und Instagram Business Login müssen zusätzlich im Meta Developer Dashboard eingerichtet sein.',
        ),
      ]);
}

class _EquipmentDialog extends StatefulWidget {
  const _EquipmentDialog({this.item});

  final EquipmentItem? item;

  @override
  State<_EquipmentDialog> createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<_EquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _description = TextEditingController(text: widget.item?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.item == null ? 'Equipment hinzufügen' : 'Equipment ändern'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Bezeichnung'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte gib eine Bezeichnung ein.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration:
                      const InputDecoration(labelText: 'Notiz (optional)'),
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
                EquipmentItem(
                  id: widget.item?.id,
                  name: _name.text.trim(),
                  description: _description.text.trim(),
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      );
}
