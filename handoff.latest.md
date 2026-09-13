# Handoff latest

Stand: 2026-09-13T09:32:00.000+02:00

## Zustand

- Active: `TD-0053`
- Status: `in-progress`
- Ziel: JA-041 IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden.
- Branch: `master`
- HEAD: `8e6aad24c3a5`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Abgeschlossener Slice

JA-041 BMW-HTTP/1.1-Fallback, BMW-Quellenwechsel und malformed-Href-Stabilisierung:

- Curl-Fehler `curl: (92)` und unsaubere HTTP/2-Streams werden als `HTTP2_STREAM_FAILED` klassifiziert und mit `--http1.1` erneut abgerufen.
- Die produktive BMW-Quelle wurde von `https://www.bmwgroup.jobs/de/en.html` auf die offiziell belegte, lokal per GET erreichbare BMW-Group-Jobs-Subdomain `https://jobs.bmwgroup.com/` korrigiert.
- Die alte `bmwgroup.jobs`-URL bleibt im Discovery-/URL-Bestand erhalten; die produktive Scan-Quelle und Seed-Quelle zeigen auf `jobs.bmwgroup.com`.
- Kaputte Fremd-Hrefs wie `http://www.sec.gov.&nbsp` brechen `ConvertFrom-JobAgentLiveCareerPage` nicht mehr ab und werden uebersprungen.
- BMW-Kontrolllauf `logs/jobagent/daily-run-20260913T073511041Z.json`: `SUCCESS`, 1 Firma, 4 Raw-Jobs/gepruefte Jobs/Snapshots, 0 unsichere Quellen, 0 nicht erreichbare Quellen, 0 Fehler, 0 Zielrollentreffer.
- Breitere Stichprobe `logs/jobagent/daily-run-20260913T073648578Z.json`: `PARTIAL`, 10 Firmen, 0 Raw-Jobs/Snapshots, 0 unsichere Quellen, 0 nicht erreichbare Quellen, 0 Fehler. Neuer offener Hotspot: `company:msg_systems_ag` mit `PARTIAL`/`NO_JOBS_FOUND`/`MANUAL_REVIEW`; 9 von 10 Firmen liefen vollstaendig `SUCCESS` ohne Treffer.

## Geaenderte Hauptdateien

- `Roadmap.md`
- `data/jobagent/store.json`
- `src/JobAgent.CompanyInventory.psm1`
- `src/JobAgent.LiveScan.psm1`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentLiveScan.ps1`
- `tests/Test-JobAgentSourceVerification.ps1`
- `docs/handoffs/2026-09-13-ja041-bmw-http1-source-handoff.md`
- `html/jobagent/daily-run-20260913T073511041Z.html`
- `html/jobagent/daily-run-20260913T073648578Z.html`
- `handoff.latest.md`
- `handoff.latest.json`
- `todo.state.json`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -CompanyIds company:bmw_group -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 30 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -MaxCompanies 10 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 30 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `0`, fachlich `PARTIAL` wegen MSG Systems `NO_JOBS_FOUND`/`MANUAL_REVIEW`
- `cmd /c .\ci.cmd devserver-status` -> Exit `0`, Port 8500 lauscht
- `Test-NetConnection localhost -Port 9000` -> Exit `0`, TCP-Port 9000 erreichbar
- `curl.exe --max-time 10 --silent --show-error http://127.0.0.1:9000/api/system/status` -> Exit `1`, Timeout
- `cmd /c .\ci.cmd sonar-start` -> Exit `1`, `docker_engine_unavailable`; direkter WSL-Start `Ubuntu-22.04` -> Exit `1`, `WSL_E_DISTRO_NOT_FOUND`
- `cmd /c .\ci.cmd route-check` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`

## Roadmap-Rotation

Keine Rotation. `TD-0053`/JA-041 bleibt offen, weil MSG-Quellen-/Adapterpruefung und erneute breitere Abschlussstichprobe noch fehlen. Nach Nutzeranweisung wurde kein Supertest gestartet.

## Naechster Anker

JA-041 fortsetzen:

1. MSG-Quelle und Adapterverhalten fuer `company:msg_systems_ag` pruefen, weil die aktuelle breite Stichprobe `NO_JOBS_FOUND`/`MANUAL_REVIEW` statt vollstaendigem Nulltreffer liefert.
2. Breitere JA-041-Abschlussstichprobe erneut laufen lassen.
3. Danach Roadmap/Todo/Handoff synchronisieren; Supertest erst bei vollstaendig abgeschlossenem Roadmap-Punkt.


