import 'package:flutter/material.dart';

class CalendarHelpView extends StatelessWidget {
  const CalendarHelpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender – So geht’s')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _HelpStep(
            number: '1',
            title: 'Eintrag erstellen',
            text:
                'Tippe auf „Eintrag“, vergib einen Titel und wähle Aufgabe oder Termin. Datum und Uhrzeit legst du über die Kalender- und Uhr-Symbole fest.',
          ),
          _HelpStep(
            number: '2',
            title: 'Aufgaben abhaken',
            text:
                'Bei Aufgaben kannst du das Kontrollkästchen abhaken. Termine bleiben als feste Einträge sichtbar.',
          ),
          _HelpStep(
            number: '3',
            title: 'CSV importieren',
            text:
                'Wähle das Import-Symbol und eine CSV-Datei mit den Spalten typ, titel, date_time und erledigt. Typen sind task oder event; Datum und Uhrzeit müssen als ISO-8601 vorliegen.',
          ),
          _HelpStep(
            number: '4',
            title: 'CSV exportieren',
            text:
                'Das Export-Symbol speichert alle sichtbaren Kalendereinträge als CSV-Datei, die du in einer Tabellenkalkulation öffnen kannst.',
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(child: Text(number)),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(title),
        ),
        subtitle: Text(text),
      ),
    );
  }
}
