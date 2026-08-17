# Handoff latest

Stand: 2026-08-17T17:19:08.604+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-020 ist begonnen, aber nicht abgeschlossen. Nächster fachlicher Einstieg bleibt TD-0016 / JA-020.`
- Branch: `master`
- HEAD: `1ef38e454fab`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: ``

## Abgeschlossener Arbeitsschritt

- `src/JobAgent.LiveScan.psm1` erweitert die Live-Lane um strukturierte JSON-LD-Extraktion fuer `JobPosting`.
- Die Live-Erkennung akzeptiert jetzt zusaetzlich ATS-typische Detail-URL-Muster, auch wenn Linktexte schwach oder generisch sind.
- Aus strukturierten Quellen werden jetzt `external_job_id`, `ats_job_id`, `location_label`, `employment_type`, `summary` und ein hoeherer `extraction_confidence` uebernommen.
- `tests/Test-JobAgentLiveScan.ps1` deckt jetzt JSON-LD-Extraktion, ATS-URL-Muster und den erfolgreichen ATS-Detailfluss ab.
- `tests/Test-JobAgentDailyRun.ps1` deckt jetzt einen Daily-Run ueber eine offizielle ATS-Quelle mit JSON-LD-`JobPosting` ab.
- `tests/Test-JobAgentSourceAdapters.ps1` blieb gruen und bestaetigt, dass der allgemeine Adaptervertrag durch die Live-Erweiterung nicht regressiert ist.

## Geaenderte Dateien

- `src/JobAgent.LiveScan.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentLiveScan.ps1`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> letzter verifizierter Digest `Exit 0`; nicht separat erneut angefordert und gemaess Nutzerregel als erledigt gewertet.

## Offene Prioritaeten

1. `TD-0016 / JA-020`
   `src/JobAgent.LiveScan.psm1`, `tests/Test-JobAgentLiveScan.ps1`, `tests/Test-JobAgentDailyRun.ps1`
   Der neue Chat soll JA-020 fertigstellen. Bereits erledigt sind JSON-LD-`JobPosting` und ein offizieller ATS-Pfad. Es fehlen noch weitere robuste Muster und Fehlerklassen gemaess Roadmap:
   - mindestens ein weiterer belegter ATS-/Karriereportaltyp neben dem aktuellen JSON-LD-/Workday-aehnlichen Pfad;
   - explizite Tests fuer blockierte Seiten, Detailfetch-Fehler und leere oder unklare Quellen;
   - klarere Fail-closed-Klassifikation fuer dynamische oder technisch limitierte Quellen, ohne Aggregatoren als Primaerquelle zu akzeptieren.
2. `TD-0017 / JA-021`
   `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tools/Seed-JobAgentCompanies.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1`
   Nach JA-020 soll das Firmeninventar quellenorientiert wachsen:
   - Discovery-Vertrag definieren;
   - Deduplikation fuer Alias/Rechtsform/Konzernvarianten erweitern;
   - Coverage-/Priorisierungslogik fuer `never_scanned`, `stale_or_unscanned` und fehlerhafte Portale nachziehen.
3. `TD-0018 / JA-022`
   `.ci/ci.config.json`, `.ci/bin/modules/*`, `tests/Test-JobAgentOperations.ps1`, `manual/PROGRAM.md`
   Danach lokalen Betrieb absichern:
   - Portvertrag `:8500` gegen bestehenden `:8300`-Stand bereinigen;
   - HTML-Audit fuer lokale Reports einfuehren;
   - Handoff/Status um oeffnungsfaehige Reportpfade erweitern.

## Wichtige Hinweise fuer den naechsten Chat

- `Roadmap.md` enthaelt weiterhin nur JA-020 bis JA-022; nichts rotieren, weil kein weiterer Roadmap-Punkt komplett abgeschlossen wurde.
- JA-020 ist nur teilweise erledigt. Der aktuelle Stand liefert einen belastbaren ersten Ausbau, aber nicht die vollstaendige Roadmap-Akzeptanz.
- Die Live-Lane darf weiterhin nur offizielle Firmen-/Karriere-/belegte ATS-Quellen verwenden. Aggregatoren bleiben strikt ausgeschlossen.
- Der neue ATS-Pfad ist bewusst deterministisch getestet; weitere Live-Pilot-Lane nur mit klar begrenzten, nicht-deterministischen Tests erweitern.
- `todo.current.md` und `todo.state.json` bleiben bei `TD-0016` bis `TD-0018` offen.
- Supertest wurde in diesem Schritt nicht neu angefordert; der letzte gruene Digest gilt gemaess Nutzerregel als ausreichend.
