# Handoff latest

Stand: 2026-08-31T07:47:30+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- HEAD: `siehe git log -1 nach Commit`
- Upstream: `origin/master`
- Worktree-Ziel: nach Commit/Push sauber
- Route: `true`
- STP: `.\ci.cmd stp` Exit `0`; anschliessend wurde der Welle-U-Fortschritt manuell in Todo/Handoff ergaenzt, weil `todo-rebuild` wegen altem Checkpoint-Schema blockiert.
- Supertest-Regel: Kein `.\ci.cmd supertest`, weil JA-027 weiter offen ist und der Nutzer funktionsbezogene Tests priorisiert.

## Aktiver Roadmap-Stand

- `JA-027` bleibt offen. Weitere offizielle Arbeitgeber wurden verifiziert und importiert; die Gesamtanforderung "jede Arbeitgeberfirma" ist noch nicht abgeschlossen.
- `UI-001` bleibt offen. Coverage-HTML bleibt lesbar und wurde mit der aktuellen Coverage neu erzeugt.
- Keine Roadmap-Rotation ausgefuehrt, weil kein aktiver Roadmap-Punkt vollstaendig abgeschlossen ist.

## Letzter abgeschlossener Slice

`JA-027` Welle U/B-Import:

- 13 offiziell belegte Arbeitgeber verarbeitet.
- 12 neue produktive Firmen: HypoVereinsbank, Instrument Systems GmbH, KNDS Deutschland GmbH & Co. KG, LfA Foerderbank Bayern, LHI Leasing GmbH, Meta Platforms Ireland Limited, Mobileye Germany GmbH, ESG Elektroniksystem- und Logistik-GmbH, HASIT Trockenmoertel GmbH, MegaZebra GmbH, innosabi GmbH, iwis SE & Co. KG.
- 1 dedupliziertes Update: Bayerische Landeszentrale fuer neue Medien.
- Store danach: 280 Firmen, 276 JobSources.
- Source Coverage danach: 278 offizielle Quellen, 277 Karrierequellen.
- Kandidatenqueue danach: 419 Kandidaten bereits produktiv verifiziert; 1365 weiter fail-closed in manueller Website-/Scope-Pruefung; 1 `RETRY_EXHAUSTED`.
- Importwellen-Gate fuer Welle B: `passed`, `manual_review_rate=0.0`, `duplicate_rate=0.0769`, `coverage_delta=12`.

## Geaenderte Artefakte

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
- `.\ci.cmd todo-rebuild` -> Exit `1`, bekannter Tooling-Blocker: `todo-rebuild: unsupported checkpoint schema`

## Umgebung

- SonarQube `http://localhost:9000/api/system/status`: `UP`, Version `26.1.0.118079`.
- Projekt-Devserver `http://127.0.0.1:8500/`: laufend, `ci.cmd devserver-status` meldet HTTP-Port `8500`.

## Naechste Aufgabe

Naechster Agent soll bei `JA-027` weitermachen:

1. Status pruefen: `git -c core.pager=cat -c color.ui=false --no-pager status --short`; `.\ci.cmd devserver-status`; Sonar API auf `:9000`.
2. Aus `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten Kandidaten mit `DISCOVER_OFFICIAL_WEBSITE`, `VERIFY_OFFICIAL_SITE` oder `MANUAL_DECISION` ermitteln.
3. Nur Kandidaten mit offizieller Firmenwebsite plus offizieller Karriere-/Jobs-/ATS-Evidenz in eine neue Welle `data/jobagent/company-discovery.official.wave-v-YYYYMMDD.json` aufnehmen.
4. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen; unsichere oder nur sekundaer belegte Kandidaten fail-closed in Review belassen.
5. Import, Queue-Refresh, Coverage/Source-Coverage und die funktionsbezogenen Tests ausfuehren.
6. Roadmap/Todo/Handoff syncen; `supertest` erst bei Abschluss von JA-027 oder expliziter Anforderung.



