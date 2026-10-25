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

   Die Migration erstellt `customers`, `projects` und `calendar_entries`.
   Jede Zeile gehört über `owner_id` genau einem angemeldeten Konto. RLS
   erzwingt die Eigentümertrennung. `projects.shotlist_daten` ist JSONB und
   speichert ausschließlich manuell gepflegte Szenen.
3. In der Meta-App unter **Instagram → API setup with Instagram Login → Set up
   Instagram business login** richte Business Login ein:

   - Füge als OAuth Redirect URI exakt
     `https://<project-ref>.supabase.co/functions/v1/api` ein.
   - Aktiviere die Berechtigungen `instagram_business_basic` und
     `instagram_business_manage_insights`.
   - Verwende die Instagram App ID und das Instagram App Secret aus diesem
     Bereich. Für echte Nutzer außerhalb der App-Rollen brauchst du Advanced
     Access und die dafür erforderliche Meta App Review.

4. Erzeuge einen AES-256-Schlüssel für die serverseitige Tokenverschlüsselung,
   zum Beispiel lokal mit `openssl rand -base64 32`. Hinterlege die Werte als
   Supabase-Edge-Function-Secrets:

   ```sh
   supabase secrets set \
     GROQ_API_KEY=<groq-key> \
     META_APP_ID=<instagram-app-id> \
     META_APP_SECRET=<instagram-app-secret> \
     META_OAUTH_REDIRECT_URI=https://<project-ref>.supabase.co/functions/v1/api \
     META_TOKEN_ENCRYPTION_KEY=<base64-aes-256-key> \
     META_GRAPH_VERSION=v26.0
   supabase functions deploy api
   ```

   Die neue Migration legt private Tabellen für einmalige OAuth-States und
   verschlüsselte Instagram-Tokens pro angemeldetem Supabase-Nutzer an. Führe
   nach dem Hinzufügen der Migration erneut `supabase db push` aus. Die
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