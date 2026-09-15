# JA-027 new chat status handoff

Stand: 2026-09-15T13:25:34.584+02:00

## Aktiver Stand

- Active: `TD-0041`
- Roadmap-Punkt: `JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand liefern`
- Status: `in-progress`
- Branch: `master`
- Letzter Funktionscommit: `16cd619 Handle domain-only career verification queue`
- Pushstatus vor diesem Handoff-Commit: `origin/master` enthaelt `16cd619`
- Roadmap-Rotation: nicht erfolgt, weil `JA-027` noch ein offenes Viewport-Audit-Gate hat.
- Supertest: nicht separat angefragt; gemaess Nutzerregel nicht als offener Blocker zu behandeln.

## Fertig seit letztem Arbeitssprung

`JA-027.3` hat den Domain-/Hostwellen-Hotspot geschlossen:

- Domain-only-Bestandsfirmen mit fehlender Karrierequelle werden wieder als `VERIFY_CAREER_SOURCE` in die Queue gebracht.
- Bereits vorher `VERIFIED` markierte Domain-only-Eintraege blockieren diese Reaktivierung nicht mehr.
- Die Kandidatenverifikation akzeptiert `VERIFY_CAREER_SOURCE` als startbare Aktion.
- `HostConcurrency` begrenzt nicht mehr die Kandidatenauswahl; der logische Batch behaelt alle priorisierten Kandidaten.
- Hostgruppen/Wellen werden ueber `logical_host_waves` dokumentiert.
- Offizielle Karriere-/ATS-Erfolge und Domain-only-Erfolge werden getrennt ausgewiesen.
- Wenn bei einem Karrierequellen-Pruefauftrag nur die Domain bestaetigt wird, bleibt der Eintrag sichtbar reviewpflichtig und wird nicht als Karrierequelle gezaehlt.

## Relevante geaenderte Dateien im Funktionscommit

- `src/JobAgent.Coverage.psm1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `Roadmap.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.checkpoint.json`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`
- `docs/handoffs/2026-09-13-ja0273-domain-hostwave-handoff.md`

## Bereits gruene Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`
- `cmd /c .\ci.cmd route-check` -> Exit `0`

## Bekannter Blocker

- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `1`
- Fehlerbild: Chrome Headless bricht lokal bei 1920 px mit `GPU process isn't usable` ab.
- Eine Gegenprobe mit zusaetzlichen Chrome-Flags hing.
- Edge wurde lokal nicht unter Standardpfad gefunden.
- Der naechste Agent soll deshalb nicht fachlich zu `JA-041` springen, sondern zuerst diese lokale Browser-/Viewport-Lane stabilisieren.

## Naechste Aufgaben

1. `tests/Test-JobAgentHtmlViewportAudit.ps1` und die verwendete Browser-Startkonfiguration pruefen.
2. Eine stabile lokale Lane fuer 390/800/1366/1920 px herstellen, bevorzugt ohne Abschwaechung der visuellen Akzeptanzkriterien.
3. Danach JA-027-Abschlussabnahme ausfuehren: relevante Funktionstests, Viewport-Audit, `cmd /c .\ci.cmd route-check`, `cmd /c .\ci.cmd stp`.
4. Bei gruenem Abschluss `JA-027` aus `Roadmap.md` nach `Roadmap_archive.md` rotieren und `TD-0041` abschliessen.
5. Erst danach `TD-0053` / `JA-041` beginnen.

## Anschlussdateien

- `Roadmap.md`
- `todo.current.md`
- `todo.state.json`
- `todo.events.jsonl`
- `handoff.latest.md`
- `handoff.latest.json`
- `tests/Test-JobAgentHtmlViewportAudit.ps1`
- `docs/handoffs/2026-09-13-ja0273-domain-hostwave-handoff.md`
