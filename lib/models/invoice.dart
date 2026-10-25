enum InvoiceDocumentType { invoice, receipt }

class InvoiceLine {
  const InvoiceLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  double get total => _roundMoney(quantity * unitPrice);

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unit_price': unitPrice,
        'line_total': total,
      };
}

class InvoiceDraft {
  const InvoiceDraft({
    required this.type,
    required this.customerName,
    required this.customerAddress,
    required this.issueDate,
    required this.lines,
    this.customerEmail = '',
    this.dueDate,
    this.smallBusiness = false,
    this.vatRate = 0.19,
    this.note = '',
  });

  final InvoiceDocumentType type;
  final String customerName;
  final String customerAddress;
  final String customerEmail;
  final DateTime issueDate;
  final DateTime? dueDate;
  final List<InvoiceLine> lines;
  final bool smallBusiness;
  final double vatRate;
  final String note;

  double get subtotal =>
      _roundMoney(lines.fold(0, (sum, line) => sum + line.total));
  double get taxAmount => smallBusiness ? 0 : _roundMoney(subtotal * vatRate);
  double get total => _roundMoney(subtotal + taxAmount);

  Map<String, dynamic> toSnapshot(Map<String, dynamic> profile) => {
        'document_type': type.name,
        'supplier': {
          'name': profile['companyName'] ?? '',
          'address': profile['companyAddress'] ?? '',
          'email': profile['companyEmail'] ?? '',
          'phone': profile['companyPhone'] ?? '',
          'tax_number': profile['taxNumber'] ?? '',
          'vat_id': profile['vatId'] ?? '',
          'bank_details': profile['bankDetails'] ?? '',
          'invoice_note': profile['invoiceNote'] ?? '',
        },
        'customer': {
          'name': customerName,
          'address': customerAddress,
          'email': customerEmail,
        },
        'issue_date': issueDate.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'lines': lines.map((line) => line.toJson()).toList(),
        'subtotal': subtotal,
        'tax_rate': smallBusiness ? 0 : vatRate,
        'tax_amount': taxAmount,
        'total': total,
        'small_business': smallBusiness,
        'small_business_note': smallBusiness
            ? 'Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.'
            : '',
        'note': note,
      };
}

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

class InvoiceDocument {
  const InvoiceDocument({
    required this.id,
    required this.documentNumber,
    required this.storagePath,
    required this.total,
    required this.finalizedAt,
    required this.sha256,
  });

  final String id;
  final String documentNumber;
  final String storagePath;
  final double total;
  final DateTime finalizedAt;
  final String sha256;

  factory InvoiceDocument.fromJson(Map<String, dynamic> json) =>
      InvoiceDocument(
        id: json['id'] as String,
        documentNumber: json['document_number'] as String,
        storagePath: json['storage_path'] as String,
        total: (json['total'] as num).toDouble(),
        finalizedAt: DateTime.parse(json['finalized_at'] as String).toLocal(),
        sha256: json['sha256'] as String,
      );
}
