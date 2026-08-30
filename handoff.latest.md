# Handoff latest

Stand: 2026-08-30T20:05:25+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- HEAD vor Commit: `ae74b90fbd0f`
- Upstream: `origin/master`
- Worktree-Ziel: nach Stage/Commit/Push sauber
- Route: `true`
- STP: ausgefuehrt mit `.\ci.cmd stp` Exit `0`
- Supertest-Regel: Wenn kein erneuter `.\ci.cmd supertest` angefragt wurde, gilt er laut aktueller Nutzeranweisung als erledigt.

## Aktiver Roadmap-Stand

- `JA-027` bleibt offen. Es wurden weitere offizielle Arbeitgeberwellen importiert, aber die Gesamtanforderung "jede Arbeitgeberfirma" ist noch nicht abgeschlossen.
- `UI-001` bleibt offen. Coverage-HTML ist bereits lesbar, aber Roadmap nennt weiterhin offene Uebertragung/Pruefung fuer alle Daily-Run-/Report-Ansichten.
- Keine Roadmap-Rotation ausgefuehrt, weil kein aktiver Roadmap-Punkt vollstaendig abgeschlossen ist.

## Letzter abgeschlossener Slice

`JA-027` Welle T/B-Import:

- 12 offiziell belegte Arbeitgeber produktiv neu aufgenommen:
  Luminovo GmbH, Magazino GmbH, Makersite GmbH, Lanes & Planes GmbH, KINEXON GmbH, Lebensversicherung von 1871 a. G. Muenchen, KPMG AG Wirtschaftspruefungsgesellschaft, Isarsoft GmbH, lingoking GmbH, Klueber Lubrication Muenchen SE & Co. KG, Westwing Group SE, zooplus SE.
- Store danach: 268 Firmen, 264 JobSources.
- Source Coverage danach: 266 offizielle Quellen, 265 Karrierequellen.
- Kandidatenqueue danach: 403 Kandidaten bereits produktiv verifiziert; 1381 Kandidaten weiter fail-closed in manueller Website-/Scope-Pruefung.
- Importwellen-Gate fuer Welle B: `passed`, `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=12`.

## Geaenderte Artefakte

- `Roadmap.md`
- `data/jobagent/company-discovery.official.wave-t-20260830.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Evidence

- `data/jobagent/company-discovery.official.wave-t-20260830.json`
- `logs/jobagent/company-discovery-import-20260830-175602.json`
- `logs/jobagent/company-candidate-verification-20260830-175607.json`
- `logs/jobagent/company-coverage-20260830-175658.json`
- `logs/jobagent/company-coverage-20260830-175658.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260830T175602708Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-t-20260830.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle T -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-t-20260830.json -WaveId B` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `rg -n "FAIL_CLOSED_REVIEW_OR_REJECT|ALREADY_VERIFIED_IN_STORE|identity-cluster:|source-registry:|Unbekannt \(|Quellen-ID" html\jobagent\company-coverage.html` -> Exit `1` als erwarteter Kein-Treffer-Check
- `.\ci.cmd stp` -> Exit `0`

## Umgebung

- SonarQube `http://localhost:9000/api/system/status`: `UP`, Version `26.1.0.118079`.
- Projekt-Devserver `http://127.0.0.1:8500/`: laufend, `ci.cmd devserver-status` meldet HTTP-Port `8500`.

## Naechste Aufgabe

Naechster Agent soll bei `JA-027` weitermachen:

1. Status pruefen: `git -c core.pager=cat -c color.ui=false --no-pager status --short`; `.\ci.cmd devserver-status`; Sonar API auf `:9000`.
2. Aus `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten Kandidaten mit `DISCOVER_OFFICIAL_WEBSITE`, `VERIFY_OFFICIAL_SITE` oder `MANUAL_DECISION` ermitteln.
3. Nur Kandidaten mit offizieller Firmenwebsite plus offizieller Karriere-/Jobs-/ATS-Evidenz in eine neue Welle `data/jobagent/company-discovery.official.wave-u-YYYYMMDD.json` aufnehmen.
4. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen; unsichere oder nur sekundaer belegte Kandidaten fail-closed in Review belassen.
5. Import mit `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-file> -WaveId B` ausfuehren.
6. Danach `Verify-JobAgentCompanyCandidates.ps1`, `Measure-JobAgentCompanyCoverage.ps1`, `Measure-JobAgentSourceCoverage.ps1` und die funktionsbezogenen Tests fuer Coverage, Candidate Verification, Import Waves, Report, HTML Audit, Viewport Audit, Source Verification, Source Adapters und Live Scan ausfuehren.
7. Roadmap/Todo/Handoff syncen; `supertest` nur laufen lassen, wenn Roadmap-Punkt abgeschlossen ist oder explizit angefragt wird. Wenn kein erneuter `supertest` angefragt wird, gilt er gemaess aktueller Nutzeranweisung als erledigt.
