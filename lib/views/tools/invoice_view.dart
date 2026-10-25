import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice.dart';
import '../../models/workspace.dart';
import '../../services/invoice_service.dart';
import '../../services/supabase_service.dart';

class _InvoiceFormResult {
  const _InvoiceFormResult(this.draft, this.supplier);

  final InvoiceDraft draft;
  final Map<String, dynamic> supplier;
}

class InvoiceView extends StatefulWidget {
  const InvoiceView({super.key});

  @override
  State<InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends State<InvoiceView> {
  final _service = SupabaseService.fromInitialized();
  final _invoiceService = InvoiceService.fromInitialized();
  CreatorProfile? _profile;
  List<InvoiceDocument> _documents = [];
  bool _loading = true;
  bool _creating = false;
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
      final results = await Future.wait([
        _service.getProfile(),
        _service.getInvoiceDocuments(),
      ]);
      _profile = results[0] as CreatorProfile;
      _documents = results[1] as List<InvoiceDocument>;
    } catch (error) {
      _error = 'Belege konnten nicht geladen werden: $error';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _create() async {
    final profile = _profile!;
    final result = await showDialog<_InvoiceFormResult>(
      context: context,
      builder: (_) => _InvoiceDialog(
        profile: profile,
        smallBusinessDefault: profile.smallBusinessDefault,
      ),
    );
    if (result == null) {
      return;
    }
    setState(() => _creating = true);
    try {
      await _invoiceService.createAndArchive(
        draft: result.draft,
        supplier: result.supplier,
      );
      await _load();
      if (mounted) {
        _message('PDF-Beleg erstellt und unveränderlich archiviert.');
      }
    } catch (error) {
      if (mounted) {
        _message('Beleg konnte nicht erstellt werden: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _share(InvoiceDocument document) async {
    try {
      await _invoiceService.share(document);
    } catch (error) {
      if (mounted) {
        _message('PDF konnte nicht geöffnet oder geteilt werden: $error');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rechnungen & Quittungen')),
      floatingActionButton: _profile == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label:
                  Text(_creating ? 'Beleg wird erstellt …' : 'Beleg erstellen'),
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
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Erstellte Dokumente werden mit fortlaufender Nummer gespeichert. Prüfe Pflichtangaben und steuerliche Behandlung vor dem Versand. Die App ersetzt keine steuerliche oder rechtliche Beratung und zertifiziert keine GoBD-Konformität.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Archiv',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (_documents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Noch keine Belege erstellt.'),
                        )
                      else
                        for (final document in _documents)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                document.documentNumber.startsWith('R-')
                                    ? Icons.receipt_long_outlined
                                    : Icons.receipt_outlined,
                              ),
                              title: Text(document.documentNumber),
                              subtitle: Text(
                                '${NumberFormat.currency(locale: 'de_DE', symbol: '€').format(document.total)} · ${DateFormat('dd.MM.yyyy HH:mm').format(document.finalizedAt)}',
                              ),
                              trailing: IconButton(
                                tooltip: 'PDF öffnen / teilen',
                                onPressed: () => _share(document),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _InvoiceDialog extends StatefulWidget {
  const _InvoiceDialog({
    required this.profile,
    required this.smallBusinessDefault,
  });

  final CreatorProfile profile;
  final bool smallBusinessDefault;

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _customerAddress = TextEditingController();
  final _customerEmail = TextEditingController();
  final _supplierName = TextEditingController();
  final _supplierAddress = TextEditingController();
  final _supplierEmail = TextEditingController();
  final _supplierPhone = TextEditingController();
  final _taxNumber = TextEditingController();
  final _vatId = TextEditingController();
  final _bankDetails = TextEditingController();
  final _note = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();
  final _vatRate = TextEditingController(text: '19');
  InvoiceDocumentType _type = InvoiceDocumentType.invoice;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  bool _smallBusiness = false;
  final List<InvoiceLine> _lines = [];

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _supplierName.text =
        profile.companyName.isEmpty ? profile.fullName : profile.companyName;
    _supplierAddress.text = profile.companyAddress;
    _supplierEmail.text = profile.companyEmail;
    _supplierPhone.text = profile.companyPhone;
    _taxNumber.text = profile.taxNumber;
    _vatId.text = profile.vatId;
    _bankDetails.text = profile.bankDetails;
    _note.text = profile.invoiceNote;
    _smallBusiness = widget.smallBusinessDefault;
    if (_smallBusiness) {
      _vatRate.text = '0';
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _customerName,
      _customerAddress,
      _customerEmail,
      _supplierName,
      _supplierAddress,
      _supplierEmail,
      _supplierPhone,
      _taxNumber,
      _vatId,
      _bankDetails,
      _note,
      _description,
      _quantity,
      _unitPrice,
      _vatRate,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final quantity =
        double.tryParse(_quantity.text.replaceAll(',', '.')) ?? double.nan;
    final price =
        double.tryParse(_unitPrice.text.replaceAll(',', '.')) ?? double.nan;
    if (_description.text.trim().isEmpty ||
        !quantity.isFinite ||
        quantity <= 0 ||
        !price.isFinite ||
        price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leistungsbeschreibung, Menge und Preis prüfen.'),
        ),
      );
      return;
    }
    setState(() {
      _lines.add(
        InvoiceLine(
          description: _description.text.trim(),
          quantity: quantity,
          unitPrice: price,
        ),
      );
      _description.clear();
      _quantity.text = '1';
      _unitPrice.clear();
    });
  }

  Future<void> _pickDate({required bool due}) async {
    final result = await showDatePicker(
      context: context,
      initialDate: due ? (_dueDate ?? _issueDate) : _issueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) {
      setState(() {
        if (due) {
          _dueDate = result;
        } else {
          _issueDate = result;
        }
      });
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Pflichtfeld.' : null;

  String? _taxIdValidator(String? value, String otherValue) {
    if (_type == InvoiceDocumentType.invoice &&
        (value == null || value.trim().isEmpty) &&
        otherValue.trim().isEmpty) {
      return 'Für Rechnungen eine Steuernummer oder USt-IdNr. angeben.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        NumberFormat.currency(locale: 'de_DE', symbol: '€', decimalDigits: 2);
    return AlertDialog(
      title: const Text('Beleg erstellen'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<InvoiceDocumentType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Dokumenttyp'),
                  items: const [
                    DropdownMenuItem(
                      value: InvoiceDocumentType.invoice,
                      child: Text('Rechnung'),
                    ),
                    DropdownMenuItem(
                      value: InvoiceDocumentType.receipt,
                      child: Text('Quittung'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Deine Absenderdaten',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _textField(_supplierName, 'Name / Unternehmen',
                    validator: _required),
                _textField(_supplierAddress, 'Vollständige Geschäftsanschrift',
                    maxLines: 2, validator: _required),
                _textField(_supplierEmail, 'E-Mail (optional)'),
                _textField(_supplierPhone, 'Telefon (optional)'),
                _textField(
                  _taxNumber,
                  'Steuernummer',
                  validator: (value) => _taxIdValidator(value, _vatId.text),
                ),
                _textField(
                  _vatId,
                  'USt-IdNr.',
                  validator: (value) => _taxIdValidator(value, _taxNumber.text),
                ),
                _textField(_bankDetails, 'Bankverbindung (optional)'),
                const Divider(height: 24),
                Text('Kunde', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _textField(_customerName, 'Name / Unternehmen',
                    validator: _required),
                _textField(
                  _customerAddress,
                  'Anschrift',
                  maxLines: 2,
                  validator:
                      _type == InvoiceDocumentType.invoice ? _required : null,
                ),
                _textField(_customerEmail, 'E-Mail (optional)'),
                const Divider(height: 24),
                Text('Leistungspositionen',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var index = 0; index < _lines.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_lines[index].description),
                    subtitle: Text(
                      '${_lines[index].quantity} × ${currency.format(_lines[index].unitPrice)} netto',
                    ),
                    trailing: IconButton(
                      tooltip: 'Position entfernen',
                      onPressed: () => setState(() => _lines.removeAt(index)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                _textField(_description, 'Leistungsbeschreibung'),
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                        _quantity,
                        'Menge',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(
                        _unitPrice,
                        'Einzelpreis netto (€)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Position hinzufügen',
                      onPressed: _addLine,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (_lines.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Nettosumme: ${currency.format(_lines.fold<double>(0, (sum, item) => sum + item.total))}',
                    ),
                  ),
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kleinunternehmerregelung (§ 19 UStG)'),
                  subtitle: const Text('Keine Umsatzsteuer ausweisen.'),
                  value: _smallBusiness,
                  onChanged: (value) => setState(() {
                    _smallBusiness = value;
                    if (value) {
                      _vatRate.text = '0';
                    } else if (_vatRate.text == '0') {
                      _vatRate.text = '19';
                    }
                  }),
                ),
                if (!_smallBusiness)
                  _textField(
                    _vatRate,
                    'Umsatzsteuer (%)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                _textField(_note, 'Zusätzlicher Hinweis (optional)',
                    maxLines: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Belegdatum: ${DateFormat('dd.MM.yyyy').format(_issueDate)}',
                      ),
                    ),
                    IconButton(
                      onPressed: () => _pickDate(due: false),
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ],
                ),
                if (_type == InvoiceDocumentType.invoice)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dueDate == null
                              ? 'Kein Fälligkeitsdatum'
                              : 'Fällig: ${DateFormat('dd.MM.yyyy').format(_dueDate!)}',
                        ),
                      ),
                      IconButton(
                        onPressed: () => _pickDate(due: true),
                        icon: const Icon(Icons.event_outlined),
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
            if (_lines.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Füge mindestens eine Position hinzu.'),
                ),
              );
              return;
            }
            final rate =
                double.tryParse(_vatRate.text.replaceAll(',', '.')) ?? 19;
            if (!_smallBusiness && (rate < 0 || rate > 100)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Der Umsatzsteuersatz muss zwischen 0 und 100 liegen.'),
                ),
              );
              return;
            }
            final supplier = {
              'companyName': _supplierName.text.trim(),
              'companyAddress': _supplierAddress.text.trim(),
              'companyEmail': _supplierEmail.text.trim(),
              'companyPhone': _supplierPhone.text.trim(),
              'taxNumber': _taxNumber.text.trim(),
              'vatId': _vatId.text.trim(),
              'bankDetails': _bankDetails.text.trim(),
              'invoiceNote': _note.text.trim(),
            };
            Navigator.pop(
              context,
              _InvoiceFormResult(
                InvoiceDraft(
                  type: _type,
                  customerName: _customerName.text.trim(),
                  customerAddress: _customerAddress.text.trim(),
                  customerEmail: _customerEmail.text.trim(),
                  issueDate: _issueDate,
                  dueDate:
                      _type == InvoiceDocumentType.invoice ? _dueDate : null,
                  lines: List.of(_lines),
                  smallBusiness: _smallBusiness,
                  vatRate: rate / 100,
                  note: '',
                ),
                supplier,
              ),
            );
          },
          child: const Text('PDF erstellen & archivieren'),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          validator: validator,
        ),
      );
}
