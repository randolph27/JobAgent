# Handoff latest

Stand: 2026-09-15T18:18:11.395+02:00

## Abschlusszustand

- `JA-042` ist vollstaendig abgeschlossen, aus `Roadmap.md` nach `Roadmap_archive.md` rotiert und durch `logs/jobagent/JA-042-3-acceptance.json` belegt. Es gibt keinen aktiven Produkt-Roadmap-Punkt und kein aktives Todo.
- Der regulaere Daily-Run scannt neu akquirierte Firmen auch dann im selben Lauf, wenn `-CompanyIds` eine explizite Scan-Auswahl setzt. Die Korrektur liegt in `src/JobAgent.DailyRun.psm1`: eine erzwungen einzuschliessende Firmen-ID umgeht ausschliesslich den expliziten Filter, nicht die Pflicht zu einer offiziellen JobSource.
- Die 1.000er-Isolationsfixture verarbeitet 1.008 Kandidaten zu 1.006 Clustern. Sie prueft Register-/Domain-Dedupe, unverschmolzene Namenskonflikte, unsichere Gebiete und stabile Cluster-IDs.
- Der Daily-Run-Test belegt zwei regulaere, isolierte Starts: erster Lauf importiert `company:example_ag` mit offizieller Karrierequelle und zwei berufsneutralen Stellen; zweiter Lauf behaelt die bekannte Firma ohne Stellen- oder Firmenduplikat und importiert genau `company:second_example_gmbh` mit einer Stelle. Der HTML-Report zeigt die neue Firma und Stelle.
- `docs/company-discovery-operations.md` beschreibt Startbefehl, getrennte Budgets, Status-/Reportpfade, Resume, `wake_at` und den Ausschluss von Busy-Wait.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
.\ci.cmd supertest
```

Alle vier Befehle endeten mit Exit 0. Der Supertest dauerte 507,07 Sekunden und enthielt den Browseraudit bei 390/800/1366/1920 px. Der erste Sandboxversuch scheiterte nur am nicht erreichbaren npm-Cache (`EPERM`); die Wiederholung mit dem vorhandenen lokalen Cache lief vollständig grün. Keine reale Firmenwelle und keine Android-Lane wurden ausgeführt.

## Persistierte Artefakte

- `logs/jobagent/JA-042-3-acceptance.json`: Abnahme, exakte Fixture-Zähler und Testbefunde.
- `html/jobagent/ui-001-browser-audit.html` und `output/playwright/ui-001-browser-audit-*.png`: im Supertest erzeugte Browseraudit-Evidence.
- `data/jobagent/company-candidate-verification.queue.json` und `html/jobagent/company-coverage.html`: vom vollständigen Testlauf neu erzeugte, versionierte Betriebsartefakte; nicht manuell verändern oder zurücksetzen.

## Nächster Auftrag: TD-0056 CI-Drift analysieren

`TD-0056` bleibt offen und ist nachrangig. Nicht blind zurücksetzen. `logs/observer/drift-latest.json` meldet eine veraltete Observer-Baseline mit Abweichungen in `manual/PROGRAM.md`, `.ci/ci.config.json`, `.ci/pins/immutable.hashes.json` und der inzwischen rotierten Roadmap. `./ci.cmd self-check` meldete zusätzlich `immutable_modified: manual/PROGRAM.md`.

Vorgehen für den nächsten Agenten:

1. Hash- und Herkunftsabgleich für `manual/PROGRAM.md`, `.ci/ci.config.json` und `.ci/pins/immutable.hashes.json`; prüfen, ob die Änderungen bewusst und vollständig sind.
2. Erst danach `./ci.cmd drift-check`, `./ci.cmd self-check` und gegebenenfalls `./ci.cmd route-check` ausführen. Keine Immutable- oder Manual-Datei ohne belegte Quelle wiederherstellen.
3. Bei belegter Bereinigung Todo/Handoff/STP synchronisieren. Ohne neuen Produktauftrag keine reale Akquise oder Firmenwelle starten.
