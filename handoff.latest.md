# Handoff latest

Stand:
2026-08-17T13:34:00+02:00

## Zustand fuer neuen Chat

- Active: _(none)_
- Status: `open`
- Naechster Arbeitsschritt: `TD-0003 / JA-005 Quellenadapter-Vertrag fuer Karriereseiten und ATS-Systeme definieren`
- Branch: `master`
- HEAD vor Abschluss-Commit: `06356534b8b9`
- Upstream: `origin/master`
- Ahead/Behind vor Abschluss-Commit: `0/0`
- Worktree: `dirty`
- Route: `JA-001` bis `JA-004` sind abgeschlossen und archiviert; aktive Roadmap startet bei `JA-005`.
- STP wurde am `2026-08-17T13:32:30+02:00` ausgefuehrt.

## Abgeschlossener Arbeitsschritt

`JA-004 Firmeninventar-Seed und Erweiterungsstrategie fuer Muenchen/Freising erstellen` ist abgeschlossen.

Implementiert:

- `src/JobAgent.CompanyInventory.psm1`
  - Seed-Erzeugung fuer Firmen im Zielraum Muenchen/Freising.
  - Standortobjekte fuer `MUNICH` und `FREISING`.
  - Domain-, Slug- und Rechtsformnormalisierung.
  - Deduplikation ueber `company_id`, kanonische Domain, rechtsformnormalisierten Namen und Aliasnamen.
  - Vorsichtige Konzern-/Tochter-Regel: gemeinsame Konzernbestandteile allein fuehren nicht zur Zusammenfuehrung.
  - Erzeugung offizieller `JobSource`-Eintraege nur bei vorhandener Karriere-URL.
- `tools/Seed-JobAgentCompanies.ps1`
  - Schreibt den Firmen-Seed transaktional ueber die bestehende Store-API.
  - Erzeugt einen Seed-Bericht unter `logs/jobagent/company-seed-*.json`.
- `data/jobagent/store.json`
  - Enthalt 12 initiale Firmen und 12 offizielle Karrierequellen.
  - Keine Stellen, keine Live-Scans, keine Bewerbungsdaten.

Schema/Dokumentation erweitert:

- `schemas/jobagent.schema.json`
- `src/JobAgent.Persistence.psm1`
- `docs/data-model.md`
- `tests/fixtures/jobagent/valid.json`

Neue Company-Felder:

- `scan_priority`
- `next_scan_at`
- `verification_status`
- `discovery_source`

## Validierung

Funktionstests erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tools\Seed-JobAgentCompanies.ps1` -> Exit `0`, 12 Firmen, 12 Quellen
- `.\ci.cmd self-check` -> Exit `0`, Log `logs\terminal\self-check-20260817-133157.log`
- `.\ci.cmd stp` -> Exit `0`

Supertest:

- Nicht erneut ausgefuehrt.
- Gemaess Nutzeranweisung gilt Supertest als erledigt, wenn er nicht angefragt wurde.
- Alter Supertest-Fehler in `logs\verify\tst-450-human-visual-supertest.md` ist kein aktueller Blocker fuer diesen Abschluss.

## Roadmap/Todo

Rausrotiert:

- `JA-004` wurde aus `Roadmap.md` entfernt und nach `Roadmap_archive.md` verschoben.

Aktiv:

1. `TD-0003 / JA-005 Quellenadapter-Vertrag fuer Karriereseiten und ATS-Systeme definieren`
2. `TD-0004 / JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren`
3. `TD-0005 / JA-007 Stellenklassifikation fuer IT-Fuehrungspositionen entwickeln`
4. `TD-0006 / JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren`
5. `TD-0007 / JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen`
6. `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`

## Konkreter Einstieg fuer JA-005

Der naechste Agent soll bei `JA-005` beginnen:

1. Adaptervertrag definieren:
   - Input: Company, Karriere-URL, Suchbegriffe, Scan-Kontext, Budget/Timeout.
   - Output: Rohjobs, offizielle Quell-URL, Detail-URL, Extraktionsvertrauen, Fehlerklasse, Retry-Empfehlung, Artefaktreferenzen.
2. Fehlerklassen verwenden:
   - `NONE`
   - `NOT_REACHABLE`
   - `TIMEOUT`
   - `BLOCKED`
   - `NO_JOBS_FOUND`
   - `UNCLEAR_SOURCE`
   - `PARSING_ERROR`
   - `TECHNICAL_LIMITATION`
3. Einen generischen HTML-/Suchseiten-Adapter und einen Fixture-Testadapter bauen.
4. Tests ohne externe Live-Webrecherche schreiben.
5. Keine Jobboerse als Primaerquelle akzeptieren.
6. Keine Live-Recherche starten, bevor `JA-006` Quellenverifikation und URL-Kanonisierung steht.

## Risiken und Annahmen

- Der Firmen-Seed ist initial und behauptet keine vollstaendige Marktabdeckung.
- Karriere-URLs koennen sich aendern; spaetere Live-Verifikation bleibt Aufgabe von `JA-005`/`JA-006`.
- Fehlende oder unsichere Werte weiter als `UNKNOWN`, `null` oder `TODO` modellieren, nicht erfinden.
- Produktive Laufzeitdaten liegen unter `data/jobagent/`; Lock- und Backup-Dateien sind ignoriert.
