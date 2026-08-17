# Handoff latest

Stand: 2026-08-17T14:27:05+02:00

## Kurzstatus

- Projekt: `JobAgent`
- Branch: `master`
- HEAD vor Commit: `525da1debd26`
- Upstream: `origin/master`
- Worktree: `dirty`
- Active: _(none)_
- Status: `open`
- Route: `JA-001` bis `JA-008` sind abgeschlossen und archiviert.
- Naechster Einstieg: `TD-0007 / JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen`

## Abgeschlossener Punkt

`JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren` ist abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert. `TD-0006` wurde aus `todo.current.md` entfernt und im Todo-Index auf `done` gesetzt.

Implementiert:

- `src/JobAgent.Deduplication.psm1`
  - `New-JobAgentJobIdentityCandidate`: erzeugt geordnete Identitaetskeys fuer `OFFICIAL_JOB_ID`, `ATS_JOB_ID`, `CANONICAL_URL` und `COMPOSITE_FINGERPRINT`.
  - `Resolve-JobAgentJobDeduplication`: entscheidet `NEW`, `KNOWN` oder `UPDATED` und liefert `job_id`, `identity_basis`, `confidence`, `changed_fields` und `reason`.
  - `Find-JobAgentExistingJobMatch`: erkennt bekannte Jobs ueber belastbare Identitaeten und beruecksichtigt `alternative_official_urls`.
  - `Get-JobAgentChangedJobFields`: meldet geaenderte Felder fuer `title`, `official_url`, `external_job_id` und `ats_job_id`.
- `tests/Test-JobAgentDeduplication.ps1`
  - Deckt zweiten Lauf derselben Stelle, offizielle Job-ID-Prioritaet, Job-ID-Wechsel bei gleicher kanonischer URL, URL-Parameter-Kanonisierung, Titelwechsel, alternative offizielle URL und echte Neuausschreibung ab.
- `tests/Test-JobAgentSupertest.ps1`
  - Buendelt Deduplikation mit den abgeschlossenen JobAgent-Funktionstests.
- `docs/data-model.md`
  - Abschnitt `Job-Deduplikation` mit Prioritaet, Grenzen und Funktionstest ergaenzt.

## Validierung

Erfolgreich:

- `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit `0`
- `Get-Content ... | ConvertFrom-Json` fuer Todo-/Handoff-JSON und `todo.events.jsonl` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd repin-immutables` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`, Log `logs\terminal\self-check-20260817-142533.log`

Hinweis: Der historische CI-Verify-Digest enthaelt weiterhin einen alten `.\ci.cmd supertest`-Fehler aus der Gradle-/Altlogik. Der fachliche JobAgent-Supertest `tests\Test-JobAgentSupertest.ps1` ist gruen. Nach Nutzerregel gilt nicht angefragter historischer Supertest nicht als Blocker.

## Offene Aufgaben

1. `TD-0007 / JA-009 Statusmaschine fuer Daily-Run-Ergebnisse und Aenderungsverlauf bauen`
   - `Resolve-JobAgentJobDeduplication` aus JA-008 fuer Treffer-Wiedererkennung nutzen.
   - Statusuebergaenge fuer ersten Lauf, unveraenderten zweiten Lauf, Update-Lauf, erfolgreiche Entfernung und invaliden Treffer implementieren.
   - `NEW -> ACTIVE -> UPDATED -> CLOSED/REMOVED` inklusive `first_seen`, `last_seen`, `changed_at` und `ChangeEvent` erzeugen.
   - Fehlgeschlagene oder partielle Firmen-Scans duerfen bestehende Stellen nicht automatisch entfernen oder schliessen.
   - Funktionstests mit Mock-Dokumenten/Mock-Scans schreiben; keine Live-Webrecherche.
2. `TD-0008 / JA-010 Deterministischen Daily-Run-Orchestrator implementieren`
   - Erst nach JA-009 sinnvoll.
   - Mock-Adapter zuerst verbinden; keine unbegrenzten Browser-/Netzwerkprozesse.
   - Fehler einzelner Firmen isolieren, ScanAttempts protokollieren und finalen Ergebnisartefakt erzeugen.

## Bekannte Risiken

- SonarQube aus diesem Projekt heraus bleibt blockiert, solange `D:\_Scripte\JobAgent\sonar.cmd` fehlt oder `localhost:9000` nicht antwortet.
- Der historische CI-Command `.\ci.cmd supertest` ist nicht identisch mit `tests\Test-JobAgentSupertest.ps1`.
