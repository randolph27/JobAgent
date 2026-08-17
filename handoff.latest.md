# Handoff latest

Stand: 2026-08-17T17:45:29.7402523+02:00

## Zustand

- Active: `TD-0017`
- Status: `in-progress`
- Ziel: `TD-0017 / JA-021 umsetzen: Firmeninventar autonom, dedupliziert und quellenorientiert erweitern.`
- Branch: `master`
- HEAD: `5753530a3dea`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`

## Abgeschlossener Arbeitsschritt

- `JA-020` ist abgeschlossen und wurde aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.
- `src/JobAgent.LiveScan.psm1` verarbeitet jetzt zusaetzlich strukturierte ATS-JSON-Listen sowie einen Lever-aehnlichen offiziellen ATS-Pfad neben JSON-LD, Workday-aehnlichen und Greenhouse-Pfaden.
- `tests/Test-JobAgentLiveScan.ps1` deckt jetzt strukturierte ATS-JSON-Extraktion, offizielle ATS-Detailseiten und die fail-closed-Faelle `BLOCKED`, `TIMEOUT`, `TECHNICAL_LIMITATION` und `NO_JOBS_FOUND` ab.
- `todo.current.md` und `todo.state.json` setzen jetzt `TD-0017 / JA-021` als aktiven Punkt; `TD-0016 / JA-020` ist erledigt.
- `./ci.cmd stp` wurde ausgefuehrt; `todo.checkpoint.json`, `todo.events.jsonl`, `todo.history.digest.json` und `todo.master.index.json` wurden synchronisiert.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `./ci.cmd stp` -> Exit `0`
- `./ci.cmd supertest` -> letzter verifizierter Digest `Exit 0`; nicht erneut separat angefragt und gemaess Nutzerregel als erledigt gewertet.

## Naechste Arbeit

1. `TD-0017 / JA-021` in `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1` und `tools/Seed-JobAgentCompanies.ps1` fortsetzen.
2. Discovery-Vertrag definieren: `discovery_source`, offizielle Website-Verifikation, Karriere-URL-Pruefung, Branche, Zielgebietsbezug und Prioritaet sauber modellieren.
3. Deduplikation erweitern: Domain, Rechtsformvarianten, Aliasnamen, Konzern-/Tochtergesellschaften und Standortbezug testen, ohne rechtlich getrennte Arbeitgeber falsch zusammenzufuehren.
4. Coverage-/Scanpriorisierung anpassen, damit `never_scanned`, `stale_or_unscanned` und `without_career_url` sichtbar und fuer Daily-Runs nutzbar werden.
5. Funktionstests fuer JA-021: `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; bei Report-Auswirkung zusaetzlich `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`.
6. Erst danach `TD-0018 / JA-022`: Devserver-Portvertrag `8500/8300` bereinigen, lokalen HTML-Audit einfuehren, Reportpfade und Betriebsstatus absichern.

## Hinweise

- Aggregatoren bleiben strikt ausgeschlossen; Discovery aus Sekundaerquellen darf nie als Verifikation behandelt werden.
- Keine neue Firma ohne belastbare Quelle aufnehmen.
- `Roadmap.md` enthaelt jetzt nur noch `JA-021` und `JA-022`; `Roadmap_archive.md` reicht jetzt bis `JA-020`.
