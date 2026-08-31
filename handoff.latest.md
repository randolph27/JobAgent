# Handoff latest

Stand: 2026-08-31T08:14:33.322+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- HEAD vor Handoff-Sync-Commit: `c963fc36a2d0`
- Upstream: `origin/master`
- Ahead/Behind vor Push: `2/0`
- Worktree-Ziel: nach Handoff-Sync-Commit und Push sauber
- Route: `true`
- STP: `.\ci.cmd stp` am 2026-08-31T08:14:33+02:00 mit Exit `0`
- Supertest: nicht erneut ausgefuehrt; gemaess Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt. JA-027 ist weiter offen, deshalb bleiben funktionsbezogene Tests massgeblich.

## Roadmap-Rotation

- Keine Rotation ausgefuehrt.
- `JA-027` ist nicht komplett erledigt: Nach Welle V sind weiterhin Kandidaten offen.
- `UI-001` ist nicht komplett erledigt: Coverage-HTML ist verbessert, Roadmap fordert aber weiterhin Uebertragung/Pruefung fuer alle Daily-Run-/Report-Ansichten.

## Letzter fachlicher Abschluss

`JA-027` Welle V/B-Import:

- 16 offiziell belegte Arbeitgeber verarbeitet.
- 15 neue produktive Firmen aufgenommen:
  MVTec Software GmbH, SimScale GmbH, NFON AG, Mytheresa, Mutares SE & Co. KGaA, HolidayCheck Group AG, Serviceplan Gruppe SE & Co. KG, Muenchner Kammerspiele, Penguin Random House Verlagsgruppe, PwC Deutschland, ORACLE Deutschland, Roche Diagnostics, Muenchner Verkehrsgesellschaft mbH, Piper Verlag GmbH, MOTORWORLD Muenchen.
- 1 dedupliziertes Update:
  Muenchner Volkstheater wurde wegen Domainmatch als Update zu `Muenchener Volkstheater GmbH` verarbeitet.
- Store danach: 295 Firmen, 292 JobSources.
- Source Coverage danach: 294 offizielle Quellen, 293 Karrierequellen.
- Kandidatenqueue danach: 442 Kandidaten bereits produktiv verifiziert; 1340 Kandidaten weiter fail-closed in manueller Website-/Scope-Pruefung; 2 Kandidaten in `VERIFY_OFFICIAL_SITE`; 1 Kandidat in `MANUAL_DECISION`.
- Importwellen-Gate fuer Welle B: `passed`, `manual_review_rate=0.0`, `duplicate_rate=0.0625`, `coverage_delta=15`.

## Geaenderte und synchronisierte Artefakte

- `Roadmap.md`
- `data/jobagent/company-discovery.official.wave-v-20260831.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Evidence

- `data/jobagent/company-discovery.official.wave-v-20260831.json`
- `logs/jobagent/company-discovery-import-20260831-060440.json`
- `logs/jobagent/company-candidate-verification-20260831-060447.json`
- `logs/jobagent/company-coverage-20260831-060540.json`
- `logs/jobagent/company-coverage-20260831-060540.md`
- `logs/jobagent/company-coverage-20260831-060716.json`
- `logs/jobagent/company-coverage-20260831-060716.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260831T060441502Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`
- STP-Archiv: `logs/todo/done-events-20260831-081433.jsonl`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-v-20260831.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest`/`curl.exe` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle V -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-v-20260831.json -WaveId B` -> Exit `0`
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

## Bekannte Tooling-Einschraenkung

- `.\ci.cmd todo-rebuild` scheiterte im vorigen Handoff reproduzierbar mit `todo-rebuild: unsupported checkpoint schema`.
- Deshalb wurden Todo-State und Handoff bei Bedarf gezielt synchronisiert. Das ist kein fachlicher Blocker fuer JA-027.

## Umgebung

- Devserver: `.\ci.cmd devserver-status` meldete zuletzt `pid=23568`, Port `8500`, `listening=True`, URL `http://localhost:8500/`.
- SonarQube: `http://localhost:9000/api/system/status` meldete zuletzt `UP`, Version `26.1.0.118079`.

## Naechster Einstieg fuer neuen Chat

1. Arbeitsbaum und Dienste pruefen:
   `git -c core.pager=cat -c color.ui=false --no-pager status --short --branch`
   `.\ci.cmd devserver-status`
   `Invoke-RestMethod -Uri http://localhost:9000/api/system/status`
2. `JA-027` fortsetzen, nicht `UI-001`, solange kein Nutzerwechsel kommt.
3. Aus `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten Kandidaten mit `next_action = DISCOVER_OFFICIAL_WEBSITE`, `VERIFY_OFFICIAL_SITE` oder `MANUAL_DECISION` ermitteln.
4. Nur Kandidaten in `data/jobagent/company-discovery.official.wave-w-YYYYMMDD.json` aufnehmen, wenn offizielle Firmenwebsite plus offizielle Karriere-/Jobs-/ATS-Evidenz belegt ist.
5. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` oder `curl.exe` pruefen; unsichere oder nur sekundaer belegte Kandidaten fail-closed in Review belassen.
6. Import ausfuehren:
   `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-w-YYYYMMDD.json -WaveId B`
7. Danach Queue-Refresh, Coverage, Source-Coverage und die funktionsbezogenen Tests ausfuehren:
   `Verify-JobAgentCompanyCandidates.ps1`, `Measure-JobAgentCompanyCoverage.ps1`, `Measure-JobAgentSourceCoverage.ps1`, `Test-JobAgentCoverage.ps1`, `Test-JobAgentCompanyCandidateVerification.ps1`, `Test-JobAgentImportWaves.ps1`, `Test-JobAgentReport.ps1`, `Test-JobAgentHtmlAudit.ps1`, `Test-JobAgentHtmlViewportAudit.ps1`, `Test-JobAgentSourceVerification.ps1`, `Test-JobAgentSourceAdapters.ps1`, `Test-JobAgentLiveScan.ps1`.
8. Roadmap/Todo/Handoff syncen; Supertest nur bei komplettem Roadmap-Abschluss oder expliziter Nutzeranforderung. Wenn Supertest nicht angefragt wurde, gilt er gemaess aktueller Nutzeranweisung als erledigt.
