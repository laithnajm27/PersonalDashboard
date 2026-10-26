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
- Eine Meta-App vom Typ Business mit Instagram API und Business Login
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

   Die Migrationen erstellen `customers`, `projects` und `calendar_entries`
   sowie Profile, Equipment, Aufgaben, Ziele, Projektlinks, Projektgalerien
   und das private Belegarchiv. Jede Zeile gehört über `owner_id` genau einem
   angemeldeten Konto. RLS erzwingt die Eigentümertrennung.
   `projects.shotlist_daten` ist JSONB und speichert ausschließlich manuell
   gepflegte Szenen; sie werden nicht automatisch erzeugt.
3. In der Meta-App unter **Instagram → API setup with Instagram Login → Set up
   Instagram business login** richte Business Login ein:

   - Verwende ausdrücklich die **Instagram App ID** aus dem Abschnitt
     **Business login settings**, nicht eine ähnlich benannte Facebook-App-ID.
   - Unter **App settings → Basic → Add platform → Website** die Domain
     hinzufügen, unter der die App läuft, und speichern. Für GitHub Pages ist
     das z. B. `https://<github-user>.github.io`; lokale Entwicklung läuft unter
     `http://localhost:8765`.
   - Füge als OAuth Redirect URI exakt
     `https://<project-ref>.supabase.co/functions/v1/api` ein.
   - Aktiviere die Berechtigungen `instagram_business_basic` und
     `instagram_business_manage_insights`.
   - Die **Embed URL** aus den Business-login-Einstellungen kann optional als
     `META_OAUTH_EMBED_URL` hinterlegt werden. Die Edge Function verwendet sie
     als Basis und prüft App-ID sowie Redirect URI vor dem Start.
   - Verwende die Instagram App ID und das Instagram App Secret aus diesem
     Bereich. Für echte Nutzer außerhalb der App-Rollen brauchst du Advanced
     Access und die dafür erforderliche Meta App Review.

4. Erzeuge einen AES-256-Schlüssel für die serverseitige Tokenverschlüsselung,
   zum Beispiel lokal mit `openssl rand -base64 32`. Hinterlege die Werte als
   Supabase-Edge-Function-Secrets:

   ```sh
   supabase secrets set \
     GROQ_API_KEY=<groq-key> \
     META_INSTAGRAM_APP_ID=<instagram-app-id-from-business-login> \
     META_APP_SECRET=<instagram-app-secret> \
     META_OAUTH_REDIRECT_URI=https://<project-ref>.supabase.co/functions/v1/api \
     META_TOKEN_ENCRYPTION_KEY=<base64-aes-256-key> \
     META_GRAPH_VERSION=v26.0
   supabase functions deploy api
   ```

   Die Instagram-Migration legt private Tabellen für einmalige OAuth-States
   und verschlüsselte Instagram-Tokens pro angemeldetem Supabase-Nutzer an.
   Die Workspace-Migration ergänzt Profil-, Equipment-, Task- und Zieldaten
   sowie Nummerierung und privaten PDF-Speicher für Belege. Führe nach jeder
   neuen Migration erneut `supabase db push` aus. Die
   Edge-Function-Callback-URL ist öffentlich erreichbar, akzeptiert aber nur
   zuvor authentifiziert gestartete, kurzlebige und einmalig verwendbare
   OAuth-States. Tokens werden AES-GCM-verschlüsselt und sind für App-Nutzer
   nicht direkt lesbar. Beim Trennen des Instagram-Kontos wird der gespeicherte
   Token aus der Datenbank entfernt.
5. In Supabase Auth E-Mail/Passwort-Anmeldung aktivieren und die erlaubten
   Redirect-URLs für die lokale URL und die GitHub-Pages-URL konfigurieren.
   Die App bietet Anmeldung und Registrierung, aber **keinen Passwort-Reset**.

Jeder angemeldete Nutzer klickt in der Instagram-Zentrale auf **Instagram-Konto
verbinden**, autorisiert sein eigenes Professional-Konto bei Instagram und
kehrt danach zum Dashboard zurück. Insights und KI-Kontext verwenden dann nur
das Instagram-Konto dieses Supabase-Nutzers. Persönliche Instagram-Konten
werden von der Instagram API nicht unterstützt; Business- oder Creator-Konten
sind erforderlich.

### Meta-Fehler „Invalid platform app“

Prüfe im Meta Developer Dashboard, ob:

1. `META_INSTAGRAM_APP_ID` wirklich die **Instagram App ID** aus **Instagram →
   API setup with Instagram Login → Business login settings** ist, nicht die
   allgemeine Meta/Facebook-App-ID.
2. In **App settings → Basic → Add platform → Website** die verwendete Live-
   Domain eingetragen und gespeichert wurde. Bei GitHub Pages: die Origin
   `https://<github-user>.github.io`.
3. Die OAuth Redirect URI unter den Instagram Business Login Settings exakt
   `https://<project-ref>.supabase.co/functions/v1/api` lautet.
4. Business Login und die beiden oben genannten Berechtigungen aktiviert sind.
   Für Nutzer, die keine App-Rollen/Tester sind, sind Advanced Access und Meta
   App Review notwendig.

Nach einer Änderung an Edge Function Secrets die Funktion erneut deployen.
Der Code kann Meta-Einstellungen außerhalb von Supabase nicht selbst ändern;
wenn die vier Werte stimmen und der Fehler bleibt, müssen App-Modus, Testrollen
und Review-Status im Meta Dashboard geprüft werden.

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

## Dashboard-Module

- **Next Up** zeigt offene Kalender- und Aufgabenpunkte der kommenden 14 Tage.
- **Pipeline** bietet Statusfilter und einen Filter für Projekte, die länger
  als 14 Tage im Status „In Arbeit“ sind.
- **Projektakte** speichert Briefing/Notizen, Kunden, Typ, Status, Ort, Zeitraum,
  Budget, Links zu Briefings und Cloud-Ordnern, projektbezogene Aufgaben sowie
  die vollständig manuelle Shotlist an einem Ort.
- **Kundengalerie** pro Projekt: Fotos und Videos (JPG, PNG, WebP, GIF, MP4,
  MOV, WebM; maximal 100 MB je Datei) werden in einem privaten Supabase-Storage-
  Bucket gespeichert. Ein zufälliger, widerrufbarer Freigabe-Link öffnet eine
  responsive Galerie ohne Kunden-Login. Medien bleiben privat; die Edge
  Function prüft den geheimen Link und erstellt kurzlebige, signierte URLs.
  Galerie-Titel, Begrüßung und Download-Schaltfläche sind einstellbar. Eine
  Download-Schaltfläche auszublenden kann nicht verhindern, dass Empfänger
  freigegebene Medien technisch speichern oder Bildschirmaufnahmen machen.
- **Kalender** bietet Monats-, Wochen- und Tagesansicht sowie CSV-Import/Export.
- **Shotlist** bleibt ausschließlich manuell; Equipment wird pro Szene
  ausgewählt und die Tabelle kann als PDF geteilt werden.
- **Rechnungen & Quittungen** werden mit laufender Nummer und PDF-Archiv
  erstellt. Finalisierte PDFs sind unveränderlich gespeichert; die Prüfsumme
  wird beim späteren Öffnen kontrolliert. Das ist jedoch
  **keine GoBD-Zertifizierung und keine steuerliche oder rechtliche Beratung**.
  Vor dem produktiven Einsatz bitte Nummernkreis, Pflichtangaben, Aufbewahrung
  und steuerliche Behandlung durch eine Steuerberatung prüfen lassen.

Profil-, Rechnungs-, Theme- und Equipmentdaten bleiben an das jeweilige
Supabase-Konto gebunden. Fehlende Absenderdaten können beim Erstellen eines
Belegs eingegeben werden; dadurch werden sie nicht automatisch im Profil
gespeichert.

## Qualitätschecks

```sh
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Es gibt bewusst weder Passwort-Reset-Logik noch UI dafür. Die Shotlist wird
ausschließlich manuell erstellt, bearbeitet und am Set abgehakt; der
KI-Assistent generiert keine Szenen.

### Kundengalerie aktivieren

Die Projekt-Migration erstellt den privaten Storage-Bucket `project-gallery`,
die Tabellen für Galerien und Medien sowie die zugehörigen RLS- und Storage-
Policies. Nach einem Push neuer Migrationen muss auch die vorhandene Edge
Function `api` erneut bereitgestellt werden, damit sie öffentliche Galerie-
Links sicher prüfen und HTML-Galerien ausliefern kann:

```sh
supabase db push
supabase functions deploy api
```

In der Projektakte eine Galerie einrichten, Medien hochladen und **Link
erstellen** auswählen. Der zufällige Link wird angezeigt und in die
Zwischenablage kopiert. Der Klartext-Link wird serverseitig nicht gespeichert;
nach einem erneuten Öffnen der Projektakte muss zum erneuten Teilen ein neuer
Link ausgestellt werden. **Link erneuern** widerruft den vorherigen Link,
**Freigabe beenden** sperrt ihn sofort. Uploads sind auf unterstützte Bild- und
Videoformate und 100 MB je Datei begrenzt. Prüfe in Supabase außerdem die
Storage-Kontingente deines Tarifs.