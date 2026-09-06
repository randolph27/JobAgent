# Übergabe – JA-040 abgeschlossen, CI-001 aktiv

Stand: 2026-09-06. Arbeitsstand ist auf `master`; der zugehörige Abschlusscommit wird nach dieser Übergabe erstellt.

## Abgeschlossener Roadmap-Punkt

`JA-040 – Jobidentität, Scanvollständigkeit und Aktualisierung korrekt absichern` ist vollständig umgesetzt und nach `Roadmap_archive.md` rotiert. `TD-0051` ist abgeschlossen. Es wurden keine historischen Job-, Scan- oder Firmenrecords umgeschrieben.

### Umgesetzter Fachvertrag

1. `src/JobAgent.LiveScan.psm1` extrahiert URL-Job-IDs nur noch aus ausdrücklich benannten Query-Parametern oder Pfadsegmenten wie `jobs/<id>` und `postings/<id>`. Der Host wird nie als ID verwendet. Die Regression deckt zwei URLs mit gleichem Host und verschiedenen Jobpfaden ab.
2. Adapter- und ScanAttempt-Ergebnisse tragen optional `scan_complete`. Ein vollständiger Erfolg ist explizit; unbekannte Legacy-Ergebnisse zählen nicht als vollständig.
3. Ein Limit, Pagination-Hinweis oder Detailabruf-Fehler erzeugt `PARTIAL` mit erhaltenen erfolgreich extrahierten Jobs, aber ohne `scan_complete`. Unvollständige und partielle Resultate dürfen keine `REMOVED`-Transition auslösen.
4. Aktualisierungen bestehender Jobs übernehmen zusätzlich zu Titel, URL, IDs und Beschreibung atomar `classification`, `priority`, `work_model` und `employment_type`; Änderungen werden als Felder im Event ausgewiesen.
5. Der Daily-Run markiert eine Firma nur dann als frischen vollständigen Erfolg, wenn alle Quellen sauber und vollständig gescannt wurden.
6. Coverage trennt `discovered`, `official_source_verified`, `live_attempted`, `live_complete`, `partial`, `blocked`, `no_matching_job`, `matching_jobs` und `legacy_successful_scans`.

## Aktueller belegter Bestand

Der generierte Coverage-Nachweis `logs/jobagent/company-coverage-20260906-052008.json` meldet 479 entdeckte Firmen, 433 offiziell verifizierte Quellen, drei Liveversuche, null vollständige Live-Scans und zwei Legacy-Erfolge. Daraus folgt ausdrücklich keine Erfüllung des 1.000er-Ziels.

## Verifikation

Folgende funktionsbezogene Tests sind erfolgreich gelaufen:

- `Test-JobAgentLiveScan.ps1`
- `Test-JobAgentDeduplication.ps1`
- `Test-JobAgentStatusMachine.ps1`
- `Test-JobAgentSourceAdapters.ps1`
- `Test-JobAgentDailyRun.ps1`
- `Test-JobAgentCoverage.ps1`
- `Test-JobAgentSchema.ps1` einschließlich AJV außerhalb der Sandbox

`./ci.cmd supertest` wurde nach dem abgeschlossenen Roadmap-Slice ausgeführt. Der Lauf scheiterte vor den weiteren Teiltests ausschließlich beim npm-Cache-Zugriff des Schema-Teiltests (`EPERM` unter `C:\Users\ralph\AppData\Local\npm-cache`). Der identische Schema-Teiltest lief außerhalb der Sandbox erfolgreich. Es besteht kein belegter fachlicher Testfehler aus JA-040; ein grüner Vollsuite-Nachweis liegt dennoch nicht vor.

`git diff --check` war vor dem Commit fehlerfrei.

## Nächster Hotspot: CI-001 / TD-0052

CI-001 ist der aktive Roadmap-Punkt. Zuerst die vorhandenen Verträge und die im Webreview dokumentierten Ursachen reproduzieren, nicht global oder pauschal reparieren:

1. `self-check` gegen mutable Roadmap-Änderungen und weiterhin wirksame Runtime-Prüfung abgrenzen; keine pauschale Neupinnung.
2. `devserver-start/status` für bestehenden Listener, PID, Prozessidentität und Loghandle robust machen. Keine fremden Prozesse beenden.
3. Sonar/Verify für den realen PowerShell-/HTML-Stack ausweisen; der aktuelle Gradle-Weg referenziert keinen vorhandenen Wrapper. Nicht unterstützte Analysen müssen als nicht ausgeführt erscheinen, nicht als bestanden.
4. Browser-/Viewport-Nachweise nur mit datierten realen Artefakten und klarer Trennung von Fixtures aktualisieren. Der alte `Test-JobAgentHtmlViewportAudit.ps1` schlug im Review am Chrome-GPU-Prozess fehl; die historische Summary ist kein aktueller Pass.
5. Ergänzende CI-Vertragstests für isolierte Prozess- und Handoff-Invarianten erstellen. Erst nach den gezielten CI-Tests den Supertest ausführen.

Primärquellen: `Roadmap.md` (CI-001), `docs/reviews/2026-09-05-webreview.md`, `docs/reviews/2026-09-05-validation.json`, `.ci/bin/modules/browser-logic.ps1`, `.ci/bin/modules/verify-logic.ps1`, `.ci/bin/modules/ci-commands-main.ps1` und `.ci/ci.config.json`.

## Grenzen

- Kein erneuter 1.000er-Abschluss, keine erfundenen Firmen, Stellen, URLs oder Vollständigkeit.
- Keine produktiven Store-Massenschreibvorgänge als Teil von CI-001.
- Nächste fachliche Produktpunkte nach CI-001: JA-027, JA-041, UI-001 und JA-042 in der Reihenfolge aus `Roadmap.md`.
