import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/supabase_service.dart';

class CustomerView extends StatefulWidget {
  const CustomerView({super.key});

  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> {
  final _service = SupabaseService.fromInitialized();
  List<Customer> _customers = [];
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
    } catch (error) {
      _error = 'Kunden konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editCustomer([Customer? customer]) async {
    final updated = await showDialog<Customer>(
      context: context,
      builder: (_) => _CustomerDialog(customer: customer),
    );
    if (updated == null) {
      return;
    }
    try {
      if (customer == null) {
        await _service.createCustomer(updated);
      } else {
        await _service.updateCustomer(updated);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Kunde konnte nicht gespeichert werden: $error');
      }
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kunde löschen?'),
        content: Text('„${customer.name}“ wirklich löschen?'),
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
    if (confirmed != true || customer.id == null) {
      return;
    }
    try {
      await _service.deleteCustomer(customer.id!);
      await _load();
    } catch (error) {
      if (mounted) {
        _showMessage('Kunde konnte nicht gelöscht werden: $error');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kunden')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCustomer(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Kunde hinzufügen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _customers.isEmpty
                  ? const Center(
                      child: Text('Noch keine Kunden angelegt.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: _customers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final customer = _customers[index];
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(customer.name),
                              subtitle: Text(
                                [
                                  customer.unternehmen,
                                  customer.email,
                                  if (customer.instagramHandle != null)
                                    '@${customer.instagramHandle}',
                                ]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                              ),
                              isThreeLine:
                                  customer.notizen?.isNotEmpty ?? false,
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    tooltip: 'Bearbeiten',
                                    onPressed: () => _editCustomer(customer),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Löschen',
                                    onPressed: () => _deleteCustomer(customer),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              onTap: () => _editCustomer(customer),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog({this.customer});

  final Customer? customer;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  static const _fields = [
    ('name', 'Name', true),
    ('unternehmen', 'Unternehmen', false),
    ('instagram', 'Instagram-Handle', false),
    ('email', 'E-Mail', false),
    ('telefon', 'Telefon', false),
    ('notizen', 'Notizen', false),
  ];

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _controllers = {
      'name': TextEditingController(text: customer?.name ?? ''),
      'unternehmen': TextEditingController(text: customer?.unternehmen ?? ''),
      'instagram': TextEditingController(
        text: customer?.instagramHandle ?? '',
      ),
      'email': TextEditingController(text: customer?.email ?? ''),
      'telefon': TextEditingController(text: customer?.telefon ?? ''),
      'notizen': TextEditingController(text: customer?.notizen ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optionalValue(String key) {
    final value = _controllers[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      Customer(
        id: widget.customer?.id,
        name: _controllers['name']!.text.trim(),
        unternehmen: _optionalValue('unternehmen'),
        instagramHandle: _optionalValue('instagram'),
        email: _optionalValue('email'),
        telefon: _optionalValue('telefon'),
        notizen: _optionalValue('notizen'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.customer == null ? 'Kunde hinzufügen' : 'Kunde ändern'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in _fields) ...[
                  TextFormField(
                    controller: _controllers[field.$1],
                    decoration: InputDecoration(labelText: field.$2),
                    maxLines: field.$1 == 'notizen' ? 3 : 1,
                    validator: field.$3
                        ? (value) => value == null || value.trim().isEmpty
                            ? 'Bitte gib einen Namen ein.'
                            : null
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
