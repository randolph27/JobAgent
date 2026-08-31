# Handoff latest

Stand: 2026-08-31T07:55:00+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- HEAD vor Handoff-Commit: `5edb3f0644eb`
- Upstream: `origin/master`
- Worktree-Ziel: nach Stage/Commit/Push sauber
- Route: `true`
- STP: `.\ci.cmd stp` am 2026-08-31T07:51:19+02:00 mit Exit `0`
- Supertest: nicht erneut ausgefuehrt; gemaess aktueller Nutzeranweisung gilt er ohne explizite Anforderung als erledigt. JA-027 ist weiter offen, deshalb bleiben funktionsbezogene Tests massgeblich.

## Roadmap-Rotation

- Keine Rotation ausgefuehrt.
- `JA-027` ist nicht komplett erledigt: Nach Welle U sind weitere Kandidaten offen.
- `UI-001` ist nicht komplett erledigt: Coverage-HTML ist verbessert, Roadmap fordert aber weiterhin Uebertragung/Pruefung fuer alle Daily-Run-/Report-Ansichten.

## Letzter fachlicher Abschluss

`JA-027` Welle U/B-Import:

- 13 offiziell belegte Arbeitgeber verarbeitet.
- 12 neue produktive Firmen aufgenommen:
  HypoVereinsbank, Instrument Systems GmbH, KNDS Deutschland GmbH & Co. KG, LfA Foerderbank Bayern, LHI Leasing GmbH, Meta Platforms Ireland Limited, Mobileye Germany GmbH, ESG Elektroniksystem- und Logistik-GmbH, HASIT Trockenmoertel GmbH, MegaZebra GmbH, innosabi GmbH, iwis SE & Co. KG.
- 1 dedupliziertes Update:
  Bayerische Landeszentrale fuer neue Medien.
- Store danach: 280 Firmen, 276 JobSources.
- Source Coverage danach: 278 offizielle Quellen, 277 Karrierequellen.
- Kandidatenqueue danach: 419 Kandidaten bereits produktiv verifiziert; 1365 Kandidaten weiter fail-closed in manueller Website-/Scope-Pruefung; 1 Kandidat `RETRY_EXHAUSTED`.
- Importwellen-Gate fuer Welle B: `passed`, `manual_review_rate=0.0`, `duplicate_rate=0.0769`, `coverage_delta=12`.

## Geaenderte und synchronisierte Artefakte

- `Roadmap.md`
- `data/jobagent/company-discovery.official.wave-u-20260831.json`
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

- `data/jobagent/company-discovery.official.wave-u-20260831.json`
- `logs/jobagent/company-discovery-import-20260831-053943.json`
- `logs/jobagent/company-candidate-verification-20260831-053950.json`
- `logs/jobagent/company-coverage-20260831-054043.json`
- `logs/jobagent/company-coverage-20260831-054043.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260831T053943989Z-pre-wave-import.json`
- Viewport-Screenshots: `output/playwright/ja-022-viewport-800.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-1920.png`
- STP-Archiv: `logs/todo/done-events-20260831-075119.jsonl`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-u-20260831.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle U -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-u-20260831.json -WaveId B` -> Exit `0`
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

- `.\ci.cmd todo-rebuild` wurde nach Welle U getestet und scheitert reproduzierbar mit `todo-rebuild: unsupported checkpoint schema`.
- Deshalb wurden Todo-State und Handoff manuell konsistent gehalten. Das ist kein fachlicher Blocker fuer JA-027.

## Umgebung

- Devserver: `.\ci.cmd devserver-status` meldet `pid=23568`, Port `8500`, `listening=True`, URL `http://localhost:8500/`.
- SonarQube: `http://localhost:9000/api/system/status` meldet `UP`, Version `26.1.0.118079`.

## Naechster Einstieg fuer neuen Chat

1. Arbeitsbaum und Dienste pruefen:
   `git -c core.pager=cat -c color.ui=false --no-pager status --short`
   `.\ci.cmd devserver-status`
   `Invoke-RestMethod -Uri http://localhost:9000/api/system/status`
2. `JA-027` fortsetzen, nicht `UI-001`, solange kein Nutzerwechsel kommt.
3. Aus `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten Kandidaten mit `next_action = DISCOVER_OFFICIAL_WEBSITE`, `VERIFY_OFFICIAL_SITE` oder `MANUAL_DECISION` ermitteln.
4. Nur Kandidaten in `data/jobagent/company-discovery.official.wave-v-YYYYMMDD.json` aufnehmen, wenn offizielle Firmenwebsite plus offizielle Karriere-/Jobs-/ATS-Evidenz belegt ist.
5. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen; unsichere oder nur sekundaer belegte Kandidaten fail-closed in Review belassen.
6. Import ausfuehren:
   `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-v-YYYYMMDD.json -WaveId B`
7. Danach Queue-Refresh, Coverage, Source-Coverage und die funktionsbezogenen Tests ausfuehren:
   `Verify-JobAgentCompanyCandidates.ps1`, `Measure-JobAgentCompanyCoverage.ps1`, `Measure-JobAgentSourceCoverage.ps1`, `Test-JobAgentCoverage.ps1`, `Test-JobAgentCompanyCandidateVerification.ps1`, `Test-JobAgentImportWaves.ps1`, `Test-JobAgentReport.ps1`, `Test-JobAgentHtmlAudit.ps1`, `Test-JobAgentHtmlViewportAudit.ps1`, `Test-JobAgentSourceVerification.ps1`, `Test-JobAgentSourceAdapters.ps1`, `Test-JobAgentLiveScan.ps1`.
8. Roadmap/Todo/Handoff syncen; `supertest` nur bei komplettem Roadmap-Abschluss oder expliziter Nutzeranforderung.
