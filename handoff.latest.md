# Handoff latest

Stand: 2026-08-17T17:28:30.000+02:00

## Zustand

- Active: `TD-0016`
- Status: `in-progress`
- Ziel: `JA-020 weiter haerten und abschliessen; JA-021 und JA-022 bleiben nachgelagert.`
- Branch: `master`
- HEAD: `99badba4b0b8`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: ``

## Abgeschlossener Arbeitsschritt

- `src/JobAgent.LiveScan.psm1` erkennt jetzt zusaetzlich Greenhouse-ATS-URLs als offizielle Detailkandidaten.
- Leere Seiten, blockierte Seiten, clientseitig/dynamische App-Shells sowie blockierte oder getimte Detailfetches werden fail-closed klassifiziert statt pauschal als unklar behandelt.
- Die JSON-LD-Hilfsfunktionen wurden gegen primitive oder uneinheitliche Nodes robust gemacht.
- `tests/Test-JobAgentLiveScan.ps1` deckt jetzt Greenhouse, blockierte Quellen, dynamische Quellen, 403-Detailfetches und 504-Detailfetches ab.
- `todo.current.md` und `todo.state.json` markieren `TD-0016` jetzt explizit als `in-progress`.
- `todo.checkpoint.json`, `todo.events.jsonl`, `todo.history.digest.json` und `todo.master.index.json` wurden ueber `./ci.cmd stp` synchronisiert.

## Geaenderte Dateien

- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.json`
- `handoff.latest.md`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `./ci.cmd stp` -> Exit `0`
- `./ci.cmd supertest` -> letzter verifizierter Digest `Exit 0`; nicht erneut separat angefordert und gemaess Nutzerregel als erledigt gewertet.

## Offene Prioritaeten

1. `TD-0016 / JA-020`
   `src/JobAgent.LiveScan.psm1`, `tests/Test-JobAgentLiveScan.ps1`, `tests/Test-JobAgentDailyRun.ps1`
   Bereits erledigt:
   - JSON-LD-`JobPosting` aus offiziellen Quellen.
   - Workday-aehnliche und Greenhouse-ATS-Detailpfade.
   - Fail-closed-Tests fuer `NO_JOBS_FOUND`, `BLOCKED`, `TECHNICAL_LIMITATION`, blockierten Detailfetch und Timeout-Detailfetch.
   Noch offen fuer Roadmap-Abnahme:
   - mindestens ein weiterer belegter offizieller Karriereportal-/ATS-Typ oder eine gleichwertige robuste Erweiterung ueber den aktuellen Satz hinaus;
   - pruefen, ob weitere strukturierte/listenbasierte offizielle Seiten noch nicht sauber extrahiert werden;
   - nach Abschluss JA-020 erst dann Roadmap/Todo/Handoff auf done drehen.
2. `TD-0017 / JA-021`
   `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tools/Seed-JobAgentCompanies.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1`
   Discovery-Vertrag, Firmenvarianten-Deduplikation und Coverage-Priorisierung erweitern.
3. `TD-0018 / JA-022`
   `.ci/ci.config.json`, `.ci/bin/modules/*`, `tests/Test-JobAgentOperations.ps1`, `manual/PROGRAM.md`
   Devserver-Portvertrag bereinigen, HTML-Audit einfuehren und lokale Reportpfade absichern.

## Wichtige Hinweise fuer den naechsten Chat

- `Roadmap.md` bleibt unveraendert offen fuer `JA-020`, `JA-021`, `JA-022`; es wurde kein Punkt komplett abgeschlossen, daher keine Rotation.
- Der naechste Chat soll bei `TD-0016 / JA-020` weitermachen, nicht bei `JA-021`.
- Aggregatoren bleiben weiterhin strikt ausgeschlossen; nur offizielle Firmen-, Karriere- oder belegte ATS-Quellen sind erlaubt.
- Wenn `JA-020` abgeschlossen wird, erst dann Roadmap-Rotation pruefen und anschliessend `JA-021` aktivieren.
