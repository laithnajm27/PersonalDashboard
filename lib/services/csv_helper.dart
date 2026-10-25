import 'package:csv/csv.dart';

import '../models/calendar.dart';

class CsvHelper {
  static const _headers = ['typ', 'titel', 'date_time', 'erledigt'];

  static String exportCalendar(List<CalendarEntry> entries) {
    final rows = <List<dynamic>>[
      _headers,
      ...entries.map(
        (entry) => [
          entry.typ.name,
          entry.titel,
          entry.dateTime.toIso8601String(),
          entry.erledigt,
        ],
      ),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static List<CalendarEntry> importCalendar(String csvText) {
    final normalized = csvText
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(normalized);
    if (rows.isEmpty) {
      return [];
    }

    final headers = rows.first
        .map((value) => value.toString().trim().toLowerCase())
        .toList();
    final indexes = {
      for (final header in _headers) header: headers.indexOf(header),
    };
    final missing = indexes.entries
        .where((entry) => entry.value < 0)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      throw FormatException('CSV-Spalten fehlen: ${missing.join(', ')}');
    }

    final entries = <CalendarEntry>[];
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every((value) => value.toString().trim().isEmpty)) {
        continue;
      }

      String cell(String name) {
        final index = indexes[name]!;
        if (row.length <= index) {
          throw FormatException(
            'CSV-Zeile ${rowIndex + 1}: Spalte "$name" fehlt.',
          );
        }
        return row[index].toString().trim();
      }

      final typeName = cell('typ').toLowerCase();
      CalendarEntryType? type;
      for (final value in CalendarEntryType.values) {
        if (value.name == typeName) {
          type = value;
          break;
        }
      }
      if (type == null) {
        throw FormatException(
          'CSV-Zeile ${rowIndex + 1}: Typ muss "task" oder "event" sein.',
        );
      }

      final dateTime = DateTime.tryParse(cell('date_time'));
      if (dateTime == null) {
        throw FormatException(
          'CSV-Zeile ${rowIndex + 1}: Ungültiges Datum/Zeit.',
        );
      }

      final doneValue = cell('erledigt').toLowerCase();
      final done = switch (doneValue) {
        'true' || '1' || 'ja' || 'yes' => true,
        'false' || '0' || 'nein' || 'no' || '' => false,
        _ => throw FormatException(
            'CSV-Zeile ${rowIndex + 1}: Ungültiger erledigt-Wert.',
          ),
      };

      final title = cell('titel');
      if (title.isEmpty) {
        throw FormatException('CSV-Zeile ${rowIndex + 1}: Titel fehlt.');
      }

      entries.add(
        CalendarEntry(
          typ: type,
          titel: title,
          dateTime: dateTime,
          erledigt: done,
        ),
      );
    }
    return entries;
  }
}
