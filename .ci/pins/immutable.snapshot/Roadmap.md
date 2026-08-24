# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das produktive Firmeninventar enthaelt aktuell nur 38 Arbeitgeber. Fuer das Ziel "alle Muenchner und Freisinger Firmen" fehlt eine skalierbare Kandidatenbasis aus Register-, Regional- und Jobboersenquellen; Vollstaendigkeit, Lizenz-/Nutzungsgrenzen, Deduplikation, Standortbezug und offizielle Karriereverifikation sind noch nicht belastbar operationalisiert.
- Priorisierung: Zuerst muessen Quellenrecht, Source Registry, Rate-Limits und Evidenzvertrag stabil sein, danach werden massentaugliche Register-/Regional-/Jobboersen-Hinweise importiert, anschliessend werden Kandidaten dedupliziert und standortbezogen bewertet, danach werden offizielle Firmen-/Karriere-/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store in Wellen auf tausende Firmen erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- [ ] JA-033 Daily-Run-HTML und Detailberichte mit klickbaren offiziellen Stellen- und Anbieterlinks vereinheitlichen #comment: Nicht nur Coverage, sondern auch Daily-Run-Berichte sollen aus jeder relevanten Ergebniszeile direkt zur offiziellen Quelle fuehren.
  - [ ] Beschreibung: Daily-Run-Markdown und Daily-Run-HTML sollen fuer neue, aktive, geaenderte und entfernte passende Stellen sowie fuer Fehler-/Quellen-Sektionen klickbare offizielle Links konsistent anzeigen. Stellenlinks nutzen `official_url`; Anbieterlinks nutzen den Linkvertrag aus JA-031. Fehlerhafte oder nicht erreichbare Quellen zeigen anklickbare Quell-URLs nur dann, wenn sie als offizielle JobSource im Store stehen; ansonsten erscheint ein nicht klickbarer Review-Grund.
  - [ ] Scope: Erweitert werden `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentDailyRun.ps1` und vorhandene HTML-/Markdown-Artefaktpruefungen. No-Go: keine Bewerbungsaktion, kein Formular-Autofill, keine Linkausgabe fuer ungesicherte Aggregator-URLs als offizielle Stelle, keine neue Live-Abhaengigkeit im Test.
  - [ ] Ist-Stand (2026-08-23 12:30): Daily-Run-Reports enthalten bereits stellenbezogene URLs in Tabellen, aber Anbieter-/Karriere-Links sind nicht als einheitlicher, getesteter Linkvertrag ueber alle Report-Sektionen abgesichert.
  - [ ] Abhängigkeiten: JA-031 und JA-032 sind abgeschlossen; Daily-Run-Reports sollen denselben Linkvertrag und dieselben Sicherheitsregeln verwenden.
  - [ ] Aufwand/Dauer: Aufwand M, Dauer 0.5-1.5 PT bei 1 Entwickler/Agent; Report- und DailyRun-Tests muessen beide laufen, weil JSON-/Markdown-/HTML-Artefakte gemeinsam betroffen sind.
  - [ ] Prioritätsscore: 82/100, weil Coverage-Links zuerst den gemeldeten Mangel beheben, Daily-Run-Links aber fuer den taeglichen Arbeitsfluss denselben Nutzen bringen.
  - [ ] Ordnungsbegründung: Nach Coverage-HTML folgt die Vereinheitlichung der Daily-Run-Ausgaben, damit neue Treffer und Betriebsberichte dieselben Linkregeln verwenden.
  - [ ] Risiken und Unsicherheiten: Manche Raw-Jobs liefern Detail-URLs mit Trackingparametern; bestehende Canonicalization muss erhalten bleiben; geschlossene Stellen koennen nicht mehr erreichbar sein und duerfen trotzdem als historische offizielle URL angezeigt werden.
  - [ ] Schritte:
    1. Report-Eintraege erweitern: `New-JobAgentReportJobEntry` und Quellen-Issue-Eintraege um Anbieterlink-Objekt oder Linktext/URL aus dem zentralen Vertrag ergaenzen, ohne bestehende Felder zu brechen.
    2. Renderer vereinheitlichen: Markdown- und HTML-Tabellen sollen Stellenlink und Anbieterlink getrennt anzeigen; HTML muss sichere `href`-Attribute und kurze Labels verwenden, Markdown muss direkt klickbare Links erzeugen.
    3. Regressionen absichern: Tests fuer aktive Stellen, neue Stellen, fehlerhafte offizielle Quellen, fehlende Anbieterlinks und HTML-Encoding ergaenzen; vorhandene Daily-Run-Fixtures duerfen keine externen Live-Abrufe ausloesen.
  - [ ] Evidence: Daily-Run-HTML unter `html/jobagent/daily-run-*.html` enthaelt klickbare Stellen- und Anbieterlinks; Markdown-Report enthaelt klickbare Links; Tests decken URL-Encoding, offizielle Quellen und fehlende Links ab.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1`.
  - [ ] Audit: Beispiel-Daily-Run im Browser pruefen: Linklabels eindeutig, offizielle Stellenlinks anklickbar, Anbieterlinks getrennt, Fehlerquellen transparent, keine Layout-Ueberlaeufe bei langen URLs.
  - [ ] Supertest: Erst nach gruenen Funktionstests `.\ci.cmd supertest`; Abschluss nur bei Exit 0.
