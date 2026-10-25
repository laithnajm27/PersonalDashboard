import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invoice.dart';
import 'pdf_export_service.dart';
import 'supabase_service.dart';

class InvoiceService {
  InvoiceService(this._client, this._database);

  factory InvoiceService.fromInitialized() => InvoiceService(
        Supabase.instance.client,
        SupabaseService.fromInitialized(),
      );

  final SupabaseClient _client;
  final SupabaseService _database;

  Future<InvoiceDocument> createAndArchive({
    required InvoiceDraft draft,
    required Map<String, dynamic> supplier,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Zum Erstellen eines Belegs musst du angemeldet sein.');
    }
    if (draft.lines.isEmpty ||
        draft.lines.any((line) =>
            line.description.trim().isEmpty ||
            !line.quantity.isFinite ||
            line.quantity <= 0 ||
            !line.unitPrice.isFinite ||
            line.unitPrice < 0)) {
      throw ArgumentError('Der Beleg enthält ungültige Positionen.');
    }
    if (!draft.total.isFinite ||
        (!draft.smallBusiness &&
            (!draft.vatRate.isFinite ||
                draft.vatRate <= 0 ||
                draft.vatRate > 1))) {
      throw ArgumentError(
          'Der Beleg enthält ungültige Steuer- oder Summenwerte.');
    }
    if ((supplier['companyName'] as String? ?? '').trim().isEmpty ||
        (supplier['companyAddress'] as String? ?? '').trim().isEmpty) {
      throw ArgumentError(
        'Absendername und vollständige Geschäftsanschrift sind Pflichtangaben.',
      );
    }
    if (draft.type == InvoiceDocumentType.invoice &&
        draft.customerAddress.trim().isEmpty) {
      throw ArgumentError(
        'Für eine Rechnung ist die vollständige Kundenanschrift erforderlich.',
      );
    }
    if (draft.type == InvoiceDocumentType.invoice &&
        (supplier['taxNumber'] as String? ?? '').trim().isEmpty &&
        (supplier['vatId'] as String? ?? '').trim().isEmpty) {
      throw ArgumentError(
        'Für eine Rechnung ist eine Steuernummer oder USt-IdNr. erforderlich.',
      );
    }

    final snapshot = draft.toSnapshot(supplier);
    final reserved = await _database.reserveInvoiceDocument(
      year: draft.issueDate.year,
      type: draft.type,
      total: draft.total,
      snapshot: snapshot,
    );
    final id = reserved['id'] as String;
    final number = reserved['document_number'] as String;
    final bytes = await PdfExportService.invoice(
      draft: draft,
      supplier: supplier,
      documentNumber: number,
    );
    final path = '${user.id}/$id.pdf';
    await _client.storage.from('invoice-pdfs').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
          ),
        );
    final checksum = sha256.convert(bytes).toString();
    await _database.completeInvoiceDocument(
      id: id,
      storagePath: path,
      sha256: checksum,
    );
    return _database.getInvoiceDocument(id);
  }

  Future<Uint8List> download(InvoiceDocument document) async {
    final bytes = await _client.storage
        .from('invoice-pdfs')
        .download(document.storagePath);
    if (sha256.convert(bytes).toString() != document.sha256) {
      throw StateError(
        'Die Prüfsumme des archivierten PDFs stimmt nicht überein.',
      );
    }
    return bytes;
  }

  Future<void> share(InvoiceDocument document) async {
    final bytes = await download(document);
    final filename = '${document.documentNumber}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
