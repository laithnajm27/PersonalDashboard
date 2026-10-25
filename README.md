# Personal Dashboard

Flutter-Dashboard für Foto- und Videograf:innen: „Dein Leben auf einen Blick“.
Die App verwaltet Kunden, Pipeline-Projekte, eine vollständig manuelle Shotlist,
Kalenderdaten und echte Instagram-Insights. Groq- und Meta-Zugangsdaten werden
ausschließlich in der Supabase Edge Function verwendet.

## Voraussetzungen

- Flutter/Dart stable (Dart 3.3 oder neuer)
- Ein Supabase-Projekt. Für den DSGVO-Betrieb beim Anlegen die Region Frankfurt
  auswählen; eine bereits erstellte Supabase-Region kann nicht nachträglich
  geändert werden.
- Supabase CLI für Datenbankmigration und Edge-Function-Deployment
- Meta Instagram Graph API-Zugang für ein Instagram Professional-Konto
- Groq API-Key für den KI-Assistenten

## Lokal starten

```sh
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key>
```

Die Supabase-Anon-Key ist für den Client vorgesehen; Tabellenzugriffe werden
zusätzlich durch Authentifizierung und Row Level Security geschützt. Service-
Role-Keys, Groq-Keys und Meta-Tokens gehören niemals in Flutter-Code, Build-
Argumente oder GitHub Pages.

## Supabase einrichten

1. Projekt in der Region Frankfurt anlegen und Projekt-URL sowie Anon-Key lokal
   bereithalten.
2. CLI anmelden und das Projekt verknüpfen:

   ```sh
   supabase login
   supabase link --project-ref <project-ref>
   supabase db push
   ```

   Die Migration erstellt `customers`, `projects` und `calendar_entries`.
   Jede Zeile gehört über `owner_id` genau einem angemeldeten Konto. RLS
   erzwingt die Eigentümertrennung. `projects.shotlist_daten` ist JSONB und
   speichert ausschließlich manuell gepflegte Szenen.
3. Für geschützte Edge-Function-Aufrufe bleibt JWT-Verifikation aktiv. Hinterlege
   die Server-Secrets und deploye die Funktion:

   ```sh
   supabase secrets set GROQ_API_KEY=<groq-key>
   supabase secrets set META_ACCESS_TOKEN=<meta-access-token>
   supabase secrets set META_INSTAGRAM_USER_ID=<instagram-professional-user-id>
   supabase secrets set META_GRAPH_VERSION=v21.0
   supabase functions deploy api
   ```

   Das Meta-Konto wird serverseitig über den vom Betreiber bereitgestellten
   Professional-Account-Token konfiguriert. „Konto verbinden“ lädt dessen
   aktuelle Graph-API-Insights; es gibt keinen clientseitigen Meta-Token und
   keinen OAuth-Token-Speicher in dieser ersten Architekturversion. Der Token
   benötigt die passenden Instagram-Graph-Berechtigungen (unter anderem
   `instagram_basic` und `instagram_manage_insights`) und muss für die
   konfigurierten Graph-API-Felder freigeschaltet sein.
4. In Supabase Auth E-Mail/Passwort-Anmeldung aktivieren und die erlaubten
   Redirect-URLs für die lokale URL und die GitHub-Pages-URL konfigurieren.
   Die App bietet Anmeldung und Registrierung, aber **keinen Passwort-Reset**.

## GitHub Pages

Das Workflow `Deploy GitHub Pages` baut die Web-App bei Pushes auf `main`.
Im GitHub-Repository unter **Settings → Secrets and variables → Actions** die
Repository-Secrets `SUPABASE_URL` und `SUPABASE_ANON_KEY` setzen und GitHub Pages
als Deployment-Quelle **GitHub Actions** auswählen. Die Web-Ausgabe verwendet
den Repository-Pfad als Base-Href. Bei einer eigenen Domain muss der Workflow
entsprechend auf `/` angepasst werden.

Für einen lokalen Web-Build:

```sh
flutter build web --release --base-href /personal_dashboard/ \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key>
```

## Android APK

Flutter erzeugt Android-APK-Dateien direkt; Capacitor ist ein Wrapper für
Web-Anwendungen und wird daher nicht zusätzlich in eine Flutter-App eingebaut.

```sh
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key>
```

## Kalender-CSV

Import und Export verwenden UTF-8 CSV mit Headern `typ,titel,date_time,erledigt`.
`typ` ist `task` oder `event`, Datum/Uhrzeit ISO-8601; boolesche Werte akzeptieren
`true`/`false`, `1`/`0` und `ja`/`nein`.

## Qualitätschecks

```sh
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Es gibt bewusst weder Passwort-Reset-Logik noch UI dafür. Die Shotlist wird
ausschließlich manuell erstellt, bearbeitet und am Set abgehakt; der
KI-Assistent generiert keine Szenen.