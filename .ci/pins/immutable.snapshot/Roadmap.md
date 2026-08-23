# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das produktive Firmeninventar enthaelt aktuell nur 38 Arbeitgeber. Fuer das Ziel "alle Muenchner und Freisinger Firmen" fehlt eine skalierbare Kandidatenbasis aus Register-, Regional- und Jobboersenquellen; Vollstaendigkeit, Lizenz-/Nutzungsgrenzen, Deduplikation, Standortbezug und offizielle Karriereverifikation sind noch nicht belastbar operationalisiert.
- Priorisierung: Zuerst muessen Quellenrecht, Source Registry, Rate-Limits und Evidenzvertrag stabil sein, danach werden massentaugliche Register-/Regional-/Jobboersen-Hinweise importiert, anschliessend werden Kandidaten dedupliziert und standortbezogen bewertet, danach werden offizielle Firmen-/Karriere-/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store in Wellen auf tausende Firmen erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- [ ] JA-030 Laufender Coverage-Betrieb, Drift-Erkennung und Quellen-Freshness fuer Muenchen/Freising etablieren #comment: Tausende Quellen veralten schnell; der Agent braucht einen Betrieb, der neue Firmen findet, alte Hinweise ablaufen laesst und Verifikationen periodisch erneuert.
  - [ ] Beschreibung: Es existiert ein Betriebsmodell fuer wiederholte Discovery-, Verifikations- und Coverage-Laeufe. Quellen haben Freshness-Intervalle, Kandidaten haben Ablaufdaten, Verifikationsbelege haben Recheck-Fristen, Jobboersen-Hinweise altern schneller als Register-/Regionalquellen und Reports zeigen Coverage nach Quelle, Gebiet, Status, Alter und naechster Aktion. Der Daily-Run priorisiert Firmen nicht nur nach Jobscan-Faelligkeit, sondern auch nach Inventar- und Quellen-Drift.
  - [ ] Scope: Erweitert werden `src/JobAgent.DailyRun.psm1`, `src/JobAgent.Coverage.psm1`, `src/JobAgent.Report.psm1`, `src/JobAgent.Operations.psm1`, `tools/Get-JobAgentDailyRunStatus.ps1`, `tests/Test-JobAgentDailyRun.ps1`, `tests/Test-JobAgentCoverage.ps1`, `tests/Test-JobAgentOperations.ps1` und Dokumentation `docs/company-discovery-operations.md`. No-Go: keine unbegrenzten Hintergrundprozesse, kein automatisches externes Schreiben, keine stille Loeschung abgelaufener Kandidaten, keine Supertest-Aufnahme von Live-Webabhaengigkeiten.
  - [ ] Ist-Stand (2026-08-23 10:00): Daily-Run, Betriebsstatus und HTML-Coverage existieren fuer kleine Bestandsdaten; Quellen-Freshness, Kandidatenablauf, Wiederverifikation und quellenbezogene Drift-Metriken fuer tausende Firmen sind nicht belegt.
  - [ ] Abhängigkeiten: JA-023 bis JA-029 muessen abgeschlossen sein; bestehender Devserver-Port `8500` und SonarQube `9000` bleiben Betriebsumgebung.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 3-6 PT bei 1 Entwickler/Agent; Report- und Operations-Tests koennen parallelisiert werden.
  - [ ] Prioritätsscore: 80/100, weil nachhaltige Inventarqualitaet nach initialer Massenerweiterung kritisch wird.
  - [ ] Ordnungsbegründung: Betrieb und Freshness folgen nach produktiven Wellen, damit reale Metriken statt hypothetischer Grenzwerte gesteuert werden.
  - [ ] Risiken und Unsicherheiten: Externe Quellen aendern Markup und Nutzungsbedingungen; grosse Reports koennen langsam werden; wiederholte Live-Pruefungen muessen Abruflimits und Fehlerbudgets einhalten.
  - [ ] Schritte:
    1. Freshness-Modell implementieren: Pro Quelle und Kandidat `last_imported_at`, `last_verified_at`, `expires_at`, `next_refresh_at`, `refresh_reason` und `staleness_status` berechnen.
    2. Drift- und Betriebsreports erweitern: Coverage nach Gebiet, Quelle, Verifikationsstatus, Alter, Review-Queue, Fehlerklasse und naechster Aktion ausgeben; HTML muss bei grossen Listen filterbar oder segmentiert bleiben.
    3. Daily-Run-Priorisierung anpassen: Firmen-Jobscan, Kandidatenverifikation und Quellenrefresh getrennt budgetieren; Live-Web bleibt ausserhalb deterministischer Supertests und wird ueber funktionale Fixture-Tests abgesichert.
  - [ ] Evidence: `docs/company-discovery-operations.md`, Betriebsstatus mit Freshness-Metriken, Coverage-HTML fuer grossen Store, Logs fuer Refresh-/Drift-Lauf, Testfixtures fuer ablaufende Quellen.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1`; Tests muessen Freshness, Ablauf, Recheck-Prioritaet, Fehlerbudgets und grosse Reports abdecken.
  - [ ] Audit: Manuell pruefen, dass Reports keine Vollstaendigkeit suggerieren, dass veraltete Hinweise sichtbar bleiben statt geloescht zu werden, dass grosse HTML-Listen keine Layoutfehler haben und dass Live-Refresh nur ueber erlaubte Quellen laeuft.
  - [ ] Supertest: Erst nach gruenen Funktionstests `.\ci.cmd supertest`; Abschluss nur bei Exit 0.
