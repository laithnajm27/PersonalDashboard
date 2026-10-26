import 'package:flutter_test/flutter_test.dart';
import 'package:personal_dashboard/models/calendar.dart';
import 'package:personal_dashboard/models/customer.dart';
import 'package:personal_dashboard/models/invoice.dart';
import 'package:personal_dashboard/models/project.dart';
import 'package:personal_dashboard/models/shotlist.dart';
import 'package:personal_dashboard/services/csv_helper.dart';
import 'package:personal_dashboard/models/workspace.dart';

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
      expect(decoded.shotlistDaten.single.equipmentIds, isEmpty);
      expect(
          decoded.shotlistDaten.single.beschreibung, 'Produkt im Sonnenlicht');
    });

    test('round-trips project planning details', () {
      final project = Project(
        id: 'project-2',
        kundeId: 'customer-1',
        titel: 'Portrait-Session',
        beschreibung: 'Natürliches Licht und warme Farben',
        ort: 'Hamburg',
        startAt: DateTime.utc(2026, 11, 1),
        dueAt: DateTime.utc(2026, 11, 14),
        budget: 850,
      );

      final decoded = Project.fromJson(project.toJson());

      expect(decoded.beschreibung, project.beschreibung);
      expect(decoded.ort, project.ort);
      expect(decoded.startAt?.toUtc(), project.startAt);
      expect(decoded.dueAt?.toUtc(), project.dueAt);
      expect(decoded.budget, 850);
    });

    test('round-trips manually assigned equipment IDs', () {
      const shot = Shotlist(
        szeneNummer: 2,
        equipmentIds: ['camera-1', 'lens-2'],
      );
      expect(Shotlist.fromJson(shot.toJson()).equipmentIds, shot.equipmentIds);
    });

    test('maps project links and project-related tasks', () {
      const link = ProjectLink(
        id: 'link-1',
        projectId: 'project-1',
        title: 'Briefing',
        url: 'https://example.com/briefing',
        note: 'Aktuelle Fassung',
      );
      const task = DashboardTask(
        id: 'task-1',
        title: 'Angebot abstimmen',
        projectId: 'project-1',
      );

      expect(ProjectLink.fromJson(link.toJson()).url, link.url);
      expect(DashboardTask.fromJson(task.toJson()).projectId, 'project-1');
    });

    test('round-trips private gallery metadata and media', () {
      const gallery = ProjectGallery(
        id: 'gallery-1',
        projectId: 'project-1',
        title: 'Sommerkampagne',
        description: 'Danke für den schönen Auftrag!',
        allowDownload: true,
        isActive: true,
      );
      const media = ProjectGalleryMedia(
        id: 'media-1',
        galleryId: 'gallery-1',
        title: 'Kampagnenfoto',
        storagePath: 'owner/gallery/image.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024,
      );

      expect(ProjectGallery.fromJson(gallery.toJson()).allowDownload, isTrue);
      expect(ProjectGalleryMedia.fromJson(media.toJson()).isVideo, isFalse);
    });
  });

  group('Workspace and invoice data mapping', () {
    test('maps in-progress task status to the database enum', () {
      const task = DashboardTask(
        title: 'Angebot nachfassen',
        status: TaskStatus.inProgress,
      );
      final json = task.toJson();
      expect(json['status'], 'in_progress');
      expect(DashboardTask.fromJson(json).status, TaskStatus.inProgress);
    });

    test('rounds invoice totals and snapshots supplier values', () {
      final draft = InvoiceDraft(
        type: InvoiceDocumentType.invoice,
        customerName: 'Musterkunde',
        customerAddress: 'Musterstraße 1',
        issueDate: DateTime(2026, 10, 25),
        lines: [
          const InvoiceLine(
            description: 'Fotoauftrag',
            quantity: 2,
            unitPrice: 12.349,
          ),
        ],
      );
      final snapshot = draft.toSnapshot({
        'companyName': 'Studio Beispiel',
        'companyAddress': 'Beispielweg 2',
        'taxNumber': '123/456/789',
      });
      expect(draft.subtotal, 24.70);
      expect(draft.taxAmount, 4.69);
      expect(draft.total, 29.39);
      expect(snapshot['supplier']['name'], 'Studio Beispiel');
      expect(snapshot['supplier']['tax_number'], '123/456/789');
      expect(snapshot['total'], draft.total);
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
