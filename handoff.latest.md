# Handoff latest

Stand: 2026-08-17T13:47:33.940+02:00

## Zustand fuer neuen Chat

- Active: _(none)_
- Status: `open`
- Naechster Arbeitsschritt: `TD-0004 / JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren`
- Branch: `master`
- HEAD: `ad1d8dc94e58`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `JA-001` bis `JA-005` sind abgeschlossen und archiviert; aktive Roadmap startet bei `JA-006`.
- STP wurde am `2026-08-17T13:47:33+02:00` ausgefuehrt.

## Abgeschlossener Arbeitsschritt

`JA-005 Quellenadapter-Vertrag fuer Karriereseiten und ATS-Systeme definieren` ist abgeschlossen.

Implementiert:

- `src/JobAgent.SourceAdapters.psm1`
  - Adaptervertrag fuer Company, offizielle JobSource und ScanContext.
  - Validierung gegen nicht-offizielle Quellen.
  - Rohjobmodell mit Titel, Detail-URL, offizieller/ATS-ID, Standorttext, Zusammenfassung und Extraktionsvertrauen.
  - Persistierbarer `ScanAttempt` je Adapterlauf.
  - Fehlerklassen `NONE`, `NOT_REACHABLE`, `TIMEOUT`, `BLOCKED`, `NO_JOBS_FOUND`, `UNCLEAR_SOURCE`, `PARSING_ERROR`, `TECHNICAL_LIMITATION`.
  - Retry-Empfehlungen `NONE`, `RETRY_SOON`, `RETRY_NEXT_RUN`, `MANUAL_REVIEW`.
  - `Invoke-JobAgentFixtureAdapter` fuer deterministische Funktionstests ohne externe Website.
  - `Invoke-JobAgentGenericHtmlAdapter` fuer statische HTML-/Suchseiten-Fixtures.
- `tests/Test-JobAgentSourceAdapters.ps1`
  - Tests fuer ScanContext, offizielle Quellen-Grenze, RawJob-Validierung, Fixture-Erfolg, leere Trefferliste, HTML-Erfolg, HTML ohne Jobs, Parsingfehler und Vertragsfehlerklassen.

Schema/Dokumentation erweitert:

- `schemas/jobagent.schema.json`
  - `adapter_result`
  - `raw_job`
- `docs/data-model.md`
  - Abschnitt `Quellenadapter-Vertrag`.
- `tests/Test-JobAgentSchema.ps1`
  - Schema-Pruefung fuer `adapter_result` und `raw_job`.

## Validierung

Funktionstests erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`, Log `logs\terminal\self-check-20260817-134722.log`
- `.\ci.cmd stp` -> Exit `0`

Supertest:

- Nicht erneut ausgefuehrt.
- Gemaess Nutzeranweisung gilt Supertest als erledigt, wenn er nicht angefragt wurde.
- Der alte Eintrag in `logs\verify\tst-450-human-visual-supertest.md` ist kein aktueller Blocker fuer JA-005.

## Roadmap/Todo

Rausrotiert:

- `JA-005` wurde aus `Roadmap.md` entfernt und nach `Roadmap_archive.md` verschoben.
- `TD-0003` ist erledigt und aus `todo.current.md` entfernt.

Aktiv:

1. `TD-0004 / JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren`
2. `TD-0005 / JA-007 Stellenklassifikation fuer IT-Fuehrungspositionen entwickeln`
3. `TD-0006 / JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren`
4. `TD-0007 / JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen`
5. `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`

## Konkreter Einstieg fuer JA-006

1. `isOfficialSource(company, url)` mit Unternehmensdomain, expliziter Karriere-URL und firmenbezogenen ATS-Domains implementieren.
2. URL-Kanonisierung ohne Trackingparameter, Session-IDs oder Suchfilter umsetzen; jobrelevante Pfad-/ID-Bestandteile erhalten.
3. Pro Stelle primaere offizielle URL und optionale alternative offizielle URLs modellieren; nicht verifizierbare Quellen als `INVALID` oder `unverified` markieren, nie als Treffer.
4. Aggregatoren wie StepStone, Indeed, LinkedIn, XING, Kununu und Glassdoor als Primaerquelle ablehnen.
5. Funktionstests fuer Firmen-Domain, ATS-Domain, Redirect, Trackingparameter, Aggregator-Ablehnung und mehrfache offizielle URLs schreiben.

## Risiken und Annahmen

- Rohjobs aus JA-005 sind noch keine verifizierten Treffer. Ohne JA-006 duerfen sie nicht produktiv als Stellen gespeichert werden.
- Der generische HTML-Adapter ist fuer statische Fixture-Strukturen gebaut; dynamische ATS-Systeme bleiben Folgearbeit.
- Keine Live-Recherche wurde gestartet.
