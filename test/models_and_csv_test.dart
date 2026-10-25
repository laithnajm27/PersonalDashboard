import 'package:flutter_test/flutter_test.dart';
import 'package:personal_dashboard/models/calendar.dart';
import 'package:personal_dashboard/models/customer.dart';
import 'package:personal_dashboard/models/project.dart';
import 'package:personal_dashboard/models/shotlist.dart';
import 'package:personal_dashboard/services/csv_helper.dart';

void main() {
  group('Customer JSON mapping', () {
    test('maps the requested customer fields to the database names', () {
      const customer = Customer(
        id: 'customer-1',
        name: 'Mira Beispiel',
        unternehmen: 'Studio Mira',
        instagramHandle: 'mira.foto',
        email: 'mira@example.com',
        telefon: '+49 123',
        notizen: 'Bevorzugt E-Mail',
      );

      expect(customer.toJson(), {
        'id': 'customer-1',
        'name': 'Mira Beispiel',
        'unternehmen': 'Studio Mira',
        'instagram_handle': 'mira.foto',
        'email': 'mira@example.com',
        'telefon': '+49 123',
        'notizen': 'Bevorzugt E-Mail',
      });
      expect(
        Customer.fromJson(customer.toJson()).instagramHandle,
        'mira.foto',
      );
    });
  });

  group('Project and manual shotlist JSON mapping', () {
    test('round-trips manually entered shotlist rows', () {
      const project = Project(
        id: 'project-1',
        kundeId: 'customer-1',
        titel: 'Sommerkampagne',
        projektTyp: ProjectType.video,
        status: 'In Arbeit',
        shotlistDaten: [
          Shotlist(
            szeneNummer: 1,
            einstellungsGroesse: 'Halbtotale',
            kameraBewegung: 'Kamerafahrt',
            beschreibung: 'Produkt im Sonnenlicht',
            audioSfx: 'Atmo',
            istErledigt: true,
          ),
        ],
      );

      final decoded = Project.fromJson(project.toJson());
      expect(decoded.projektTyp, ProjectType.video);
      expect(decoded.shotlistDaten.single.szeneNummer, 1);
      expect(decoded.shotlistDaten.single.istErledigt, isTrue);
      expect(
          decoded.shotlistDaten.single.beschreibung, 'Produkt im Sonnenlicht');
    });
  });

  group('Calendar CSV', () {
    test('exports and imports quoted titles and task state', () {
      final original = [
        CalendarEntry(
          typ: CalendarEntryType.task,
          titel: 'Kunde, Angebot senden',
          dateTime: DateTime.utc(2026, 10, 25, 9, 30),
          erledigt: true,
        ),
      ];

      final imported = CsvHelper.importCalendar(
        CsvHelper.exportCalendar(original),
      );
      expect(imported, hasLength(1));
      expect(imported.single.titel, 'Kunde, Angebot senden');
      expect(imported.single.typ, CalendarEntryType.task);
      expect(imported.single.erledigt, isTrue);
      expect(imported.single.dateTime.toUtc(), original.single.dateTime);
    });

    test('rejects CSV rows with an unknown entry type', () {
      expect(
        () => CsvHelper.importCalendar(
          'typ,titel,date_time,erledigt\\nreminder,Test,2026-10-25T09:00:00Z,false',
        ),
        throwsFormatException,
      );
    });
  });
}
