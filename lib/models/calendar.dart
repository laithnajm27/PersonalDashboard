enum CalendarEntryType { task, event }

class CalendarEntry {
  const CalendarEntry({
    this.id,
    required this.typ,
    required this.titel,
    required this.dateTime,
    this.erledigt = false,
  });

  final String? id;
  final CalendarEntryType typ;
  final String titel;
  final DateTime dateTime;
  final bool erledigt;

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    CalendarEntryType? type;
    for (final value in CalendarEntryType.values) {
      if (value.name == json['typ']) {
        type = value;
        break;
      }
    }
    final title = json['titel'];
    final dateValue = json['date_time'];
    final id = json['id']?.toString();
    if (type == null || id == null || title is! String || title.isEmpty) {
      throw const FormatException('Kalendereintrag ist unvollständig.');
    }
    if (dateValue is! String) {
      throw const FormatException('Kalendereintrag hat kein gültiges Datum.');
    }
    final dateTime = DateTime.tryParse(dateValue);
    if (dateTime == null) {
      throw const FormatException('Kalendereintrag hat kein gültiges Datum.');
    }
    return CalendarEntry(
      id: id,
      typ: type,
      titel: title,
      dateTime: dateTime.toLocal(),
      erledigt: json['erledigt'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) => {
        if (includeId && id != null) 'id': id,
        'typ': typ.name,
        'titel': titel,
        'date_time': dateTime.toUtc().toIso8601String(),
        'erledigt': erledigt,
      };
}
