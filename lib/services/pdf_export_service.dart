import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import '../models/project.dart';
import '../models/shotlist.dart';
import '../models/workspace.dart';

class PdfExportService {
  static final _money =
      NumberFormat.currency(locale: 'de_DE', symbol: '€', decimalDigits: 2);
  static final _date = DateFormat('dd.MM.yyyy');

  static Future<Uint8List> shotlist({
    required Project project,
    required List<Shotlist> shots,
    required List<EquipmentItem> equipment,
  }) async {
    final equipmentNames = {
      for (final item in equipment)
        if (item.id != null) item.id!: item.name,
    };
    final document = pw.Document(
      title: 'Shotlist – ${project.titel}',
      author: 'Personal Dashboard',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          margin: const pw.EdgeInsets.only(bottom: 18),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PERSONAL DASHBOARD',
                style: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.2,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                _date.format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(
            'Shotlist',
            style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            project.titel,
            style: const pw.TextStyle(fontSize: 15, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          if (shots.isEmpty)
            pw.Text('Für dieses Projekt wurden noch keine Szenen eingetragen.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Nr.',
                'Einstellung',
                'Kamerabewegung',
                'Beschreibung',
                'Audio / SFX',
                'Equipment',
                'Status',
              ],
              data: [
                for (final shot in shots)
                  [
                    '${shot.szeneNummer}',
                    _dash(shot.einstellungsGroesse),
                    _dash(shot.kameraBewegung),
                    _dash(shot.beschreibung),
                    _dash(shot.audioSfx),
                    _dash(
                      shot.equipmentIds
                          .map((id) => equipmentNames[id] ?? '')
                          .where((name) => name.isNotEmpty)
                          .join(', '),
                    ),
                    shot.istErledigt ? 'Erledigt' : 'Offen',
                  ],
              ],
              headerStyle: const pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 8,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FixedColumnWidth(58),
                2: const pw.FixedColumnWidth(64),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FixedColumnWidth(54),
                5: const pw.FixedColumnWidth(70),
                6: const pw.FixedColumnWidth(42),
              },
            ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Diese Shotlist enthält ausschließlich manuell eingetragene Szenen.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }

  static Future<Uint8List> invoice({
    required InvoiceDraft draft,
    required Map<String, dynamic> supplier,
    required String documentNumber,
  }) async {
    final document = pw.Document(
      title:
          '${draft.type == InvoiceDocumentType.invoice ? 'Rechnung' : 'Quittung'} $documentNumber',
      author: 'Personal Dashboard',
    );
    final title =
        draft.type == InvoiceDocumentType.invoice ? 'Rechnung' : 'Quittung';
    final supplierName = _value(supplier, 'companyName');
    final supplierAddress = _value(supplier, 'companyAddress');
    final vat = draft.taxAmount;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              supplierName.toUpperCase(),
              style: const pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              '$title · $documentNumber',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 35),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('EMPFÄNGER', style: _labelStyle),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      draft.customerName,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (draft.customerAddress.isNotEmpty)
                      pw.Text(draft.customerAddress,
                          style: const pw.TextStyle(fontSize: 10)),
                    if (draft.customerEmail.isNotEmpty)
                      pw.Text(draft.customerEmail,
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(title.toUpperCase(), style: _labelStyle),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      documentNumber,
                      style: const pw.TextStyle(
                        fontSize: 19,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Datum: ${_date.format(draft.issueDate)}'),
                    if (draft.dueDate != null)
                      pw.Text('Fällig: ${_date.format(draft.dueDate!)}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 34),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Leistung',
              'Menge',
              'Einzelpreis netto',
              'Betrag netto'
            ],
            data: [
              for (final line in draft.lines)
                [
                  line.description,
                  line.quantity.toStringAsFixed(2),
                  _money.format(line.unitPrice),
                  _money.format(line.total),
                ],
            ],
            headerStyle: const pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300),
              bottom: pw.BorderSide(color: PdfColors.grey500),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FixedColumnWidth(48),
              2: const pw.FixedColumnWidth(98),
              3: const pw.FixedColumnWidth(95),
            },
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _totalRow('Nettobetrag', _money.format(draft.subtotal)),
                  if (!draft.smallBusiness)
                    _totalRow(
                      'Umsatzsteuer ${(draft.vatRate * 100).toStringAsFixed(0)} %',
                      _money.format(vat),
                    ),
                  pw.Divider(color: PdfColors.grey600),
                  _totalRow(
                    'Gesamtbetrag',
                    _money.format(draft.total),
                    strong: true,
                  ),
                ],
              ),
            ),
          ),
          if (draft.smallBusiness) ...[
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Text(
                'Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
          if (draft.note.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(draft.note.trim(), style: const pw.TextStyle(fontSize: 9)),
          ],
          if (_value(supplier, 'invoiceNote').isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              _value(supplier, 'invoiceNote'),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(supplierName,
                        style: const pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    if (supplierAddress.isNotEmpty)
                      pw.Text(supplierAddress,
                          style: const pw.TextStyle(fontSize: 8)),
                    if (_value(supplier, 'companyEmail').isNotEmpty)
                      pw.Text(
                        _value(supplier, 'companyEmail'),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (_value(supplier, 'companyPhone').isNotEmpty)
                      pw.Text(
                        _value(supplier, 'companyPhone'),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ),
              if (_value(supplier, 'taxNumber').isNotEmpty ||
                  _value(supplier, 'vatId').isNotEmpty)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (_value(supplier, 'taxNumber').isNotEmpty)
                        pw.Text(
                          'Steuernummer: ${_value(supplier, 'taxNumber')}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (_value(supplier, 'vatId').isNotEmpty)
                        pw.Text(
                          'USt-IdNr.: ${_value(supplier, 'vatId')}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (_value(supplier, 'bankDetails').isNotEmpty)
                        pw.Text(
                          _value(supplier, 'bankDetails'),
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  static pw.Widget _totalRow(String label, String value,
          {bool strong = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: strong ? 12 : 9,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: strong ? 12 : 9,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  static const _labelStyle = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    letterSpacing: 1,
    color: PdfColors.grey700,
  );

  static String _value(Map<String, dynamic> values, String key) {
    final value = values[key];
    return value is String ? value.trim() : '';
  }

  static String _dash(String value) =>
      value.trim().isEmpty ? '—' : value.trim();
}
