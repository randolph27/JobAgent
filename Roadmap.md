# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das produktive Firmeninventar enthaelt aktuell nur 38 Arbeitgeber. Fuer das Ziel "alle Muenchner und Freisinger Firmen" fehlt eine skalierbare Kandidatenbasis aus Register-, Regional- und Jobboersenquellen; Vollstaendigkeit, Lizenz-/Nutzungsgrenzen, Deduplikation, Standortbezug und offizielle Karriereverifikation sind noch nicht belastbar operationalisiert.
- Priorisierung: Zuerst muessen Quellenrecht, Source Registry, Rate-Limits und Evidenzvertrag stabil sein, danach werden massentaugliche Register-/Regional-/Jobboersen-Hinweise importiert, anschliessend werden Kandidaten dedupliziert und standortbezogen bewertet, danach werden offizielle Firmen-/Karriere-/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store in Wellen auf tausende Firmen erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- [ ] JA-039 Quellenbestand, Quellenanzahl und Scanabdeckung im Bericht transparent ausweisen #comment: Die Frage nach der aktuellen Quellenanzahl muss direkt aus Store und Source Registry beantwortbar und im HTML-Bericht sichtbar sein.
  - [ ] Beschreibung: Der JobAgent weist im Coverage- und Daily-Run-Output klar aus, wie viele Quellen aktuell vorhanden sind, wie viele davon offizielle Firmen-/Karriere-/ATS-Quellen sind, wie viele nur Discovery-Hinweise sind, wie viele im letzten Lauf gescannt wurden und wie viele wegen Retry, Blockade, fehlender Verifikation oder fehlender Karriere-URL offen sind. Die Zahlen muessen deterministisch aus `data/jobagent/store.json`, Source Registry und Laufartefakten berechnet werden; es darf keine geschaetzte oder manuell eingetragene Quellenzahl geben.
  - [ ] Scope: Anpassen `src/JobAgent.Coverage.psm1`, `src/JobAgent.Report.psm1`, optional neues Tool `tools/Measure-JobAgentSourceCoverage.ps1` oder Erweiterung vorhandener Coverage-Tools, Tests `tests/Test-JobAgentCoverage.ps1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentOperations.ps1` falls CLI-Status erweitert wird. No-Go: keine Live-Netzwerkabfrage fuer reine Zaehllogik, keine Bewertung von Jobboersen als offizielle Primaerquelle, keine Vermischung von Firmenanzahl und Quellenanzahl.
  - [ ] Ist-Stand (2026-08-24 09:56): Der Nutzer fragt explizit, wie viele Quellen aktuell vorhanden sind. Sichtbare Coverage-Wellen zeigen einzelne Firmen und Links, aber keine zusammenfassende Quellenanzahl nach Typ, Verifikation und Scanstatus. Aktueller Daily-Run vom 2026-08-24 erzeugte 25 gescannte Firmen und 26 Adapterversuche, beantwortet aber nicht die Gesamtzahl aller verfuegbaren Quellen im Bestand.
  - [ ] Screenshot-Referenz: TODO: Der Nutzer-Screenshot liegt im Chat vor, aber noch nicht als lokale Datei unter `doc/roadmap-screenshots/`. Beim Umsetzungsstart Screenshot lokal speichern als `doc/roadmap-screenshots/JA-039-report-missing-source-count-current.png`; bindendes Fehlerbild ist, dass Wellen Tabellenzeilen zeigen, aber keine Gesamtzahl und keine Aufschluesselung nach Quelltyp/Status.
  - [ ] Schritte:
    1. Eine reine Berechnungsfunktion fuer Quellenmetriken implementieren: Gesamtquellen, offizielle Quellen, Karrierequellen, ATS-Quellen, Discovery-/Review-Quellen, verifizierte Quellen, unverified/retry/blockiert, im letzten Lauf versucht, erfolgreich gescannt, nie gescannt und stale; Tests muessen leeren Store, nur Firmen ohne Quellen, gemischte Source-Typen und doppelte Quellen abdecken.
    2. Coverage- und Daily-Run-Report um eine kompakte Quellen-Kachelgruppe und eine Detailtabelle erweitern; Bezeichnungen muessen fachlich deutsch sein, Prozentwerte nur berechnen, wenn Nenner > 0 ist, und unbekannte Werte klar als `Nicht verfuegbar` markieren.
    3. Einen schnellen CLI-/Statuspfad bereitstellen, der die Frage `wieviele quellen haben wir im moment` ohne Daily-Run beantwortet, zum Beispiel ueber bestehendes Coverage-Tool oder neues `Measure-JobAgentSourceCoverage.ps1`; Ausgabe als JSON und optional Markdown, ohne Store zu veraendern.
  - [ ] Evidence: Quellenmetrik-JSON oder CLI-Ausgabe mit aktueller Gesamtzahl; HTML-Bericht mit Quellenuebersicht; Testlog `logs/verify/ja-039-source-count.md`; aktualisierte Tests fuer Quellenmetriken; kein Diff mit erfundenen Quellen.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`; falls neues Tool entsteht: `pwsh -NoProfile -File tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent`.
  - [ ] Audit: Bei 1920, 1366 und 800 Pixel Breite pruefen, dass Quellenzahlen oberhalb der langen Tabellen sichtbar sind, die Begriffe `Quelle`, `offiziell`, `Discovery-Hinweis`, `gescannt`, `offen` eindeutig lesbar sind und keine internen Feldnamen wie `job_sources`, `source_id` oder `is_official` als primaere Labels erscheinen.
  - [ ] Supertest: `.\ci.cmd supertest` erst nach gruenem Quellenmetrik-Funktionstest und HTML-Audit ausfuehren.
  - [ ] Abhaengigkeiten: Fachlich unabhaengig von JA-038; sollte mit JA-037 abgestimmt werden, damit neue Quellenlabels nicht doppelt gepflegt werden.
  - [ ] Aufwand: M, geschaetzt 4-8 Stunden bei 1 Entwickler/Agent inklusive Tool-/Reporttests.
  - [ ] Dauer: 1 Arbeitstag lokal; Berechnungsfunktion und UI-Rendering koennen teilweise parallel bearbeitet werden.
  - [ ] Prioritaetsscore: 94.
  - [ ] Ordnungsbegruendung: Die Quellenanzahl ist eine konkrete Steuerungsfrage fuer den Ausbau; die Umsetzung ist datengetrieben und reduziert Unsicherheit im Daily-Betrieb.
  - [ ] Risiken und Unsicherheiten: Aktuelle Store-Felder koennen Quellen und Discovery-Hints getrennt modellieren; die Definition `Quelle` muss deshalb im Punkt festgelegt und getestet werden, damit Firmen, Jobquellen und Hinweisquellen nicht versehentlich zusammengezaehlt werden.
  - [ ] Meilenstein: M6-C Quellenbestand messbar und sichtbar.


