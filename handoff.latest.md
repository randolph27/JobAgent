# Handoff latest

Stand: 2026-08-30T19:50:00+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Branch: `master`
- Upstream: `origin/master`
- Worktree-Ziel: nach Stage/Commit/Push sauber
- Route: `true`
- Supertest-Regel: Wenn `.\ci.cmd supertest` in diesem Abschluss nicht erneut angefragt wurde, gilt er laut Nutzeranweisung als erledigt.

## Aktiver Roadmap-Stand

- `JA-027` bleibt offen. Es wurden weitere offizielle Arbeitgeberwellen importiert, aber die Gesamtanforderung "jede Arbeitgeberfirma" ist noch nicht abgeschlossen.
- `UI-001` bleibt offen. Coverage-HTML ist bereits lesbar und technisch bereinigt, aber Roadmap nennt weiterhin offene Uebertragung/Pruefung fuer alle Daily-Run-/Report-Ansichten.
- Keine Roadmap-Rotation ausgefuehrt, weil kein aktiver Roadmap-Punkt vollstaendig abgeschlossen ist.

## Letzter abgeschlossener Slice

`JA-027` Welle S/B-Import:

- 14 offiziell belegte Arbeitgeber produktiv aufgenommen:
  Generali Deutschland AG, HENN GmbH, HAWK:AI GmbH, HCM4all GmbH, Graefe und Unzer Verlag GmbH, HORNBACH Baumarkt AG, CosmosIndex GmbH, Bleenco GmbH, Hamberger Grossmarkt GmbH, factor product GmbH, Huawei Technologies Deutschland GmbH, Porsche eBike Performance GmbH, GlaxoSmithKline GmbH & Co. KG, Hexal AG.
- Store danach: 256 Firmen, 252 JobSources.
- Source Coverage danach: 254 offizielle Quellen, 253 Karrierequellen.
- Kandidatenqueue danach: 388 Kandidaten bereits produktiv verifiziert; 1394 Kandidaten weiter fail-closed in manueller Website-/Scope-Pruefung; 2 Kandidaten in `VERIFY_OFFICIAL_SITE`; 1 Kandidat in `MANUAL_DECISION`.
- Importwellen-Gate fuer Welle B: `passed`, `manual_review_rate=0.0`, `duplicate_rate=0.0`, `coverage_delta=14`.

## Geaenderte Artefakte

- `Roadmap.md`
- `data/jobagent/company-discovery.official.wave-s-20260830.json`
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

- `data/jobagent/company-discovery.official.wave-s-20260830.json`
- `logs/jobagent/company-discovery-import-20260830-173914.json`
- `logs/jobagent/company-candidate-verification-20260830-173921.json`
- `logs/jobagent/company-coverage-20260830-173922.json`
- `logs/jobagent/company-coverage-20260830-173922.md`
- `logs/jobagent/ja-023-source-coverage.json`
- `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260830T173914765Z-pre-wave-import.json`

## Verifikation

- `Get-Content -Raw data\jobagent\company-discovery.official.wave-s-20260830.json | ConvertFrom-Json -Depth 100` -> Exit `0`
- `Invoke-WebRequest -Method Get` fuer alle `official_website_url`/`career_url`/`discovery_url` aus Welle S -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-s-20260830.json -WaveId B` -> Exit `0`
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
- Projekt-Devserver `http://127.0.0.1:8500/html/jobagent/company-coverage.html`: HTTP `200`.
- Port `8090`: Verbindung verweigert. Nicht gestartet, weil aktueller Projekt-CI-Devserver auf `8500` laeuft und `ci.cmd devserver-status` dies bestaetigt.

## Naechste Aufgabe

Naechster Agent soll bei `JA-027` weitermachen:

1. `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md` lesen.
2. Status pruefen: `git -c core.pager=cat -c color.ui=false --no-pager status --short`; `.\ci.cmd devserver-status`; Sonar API auf `:9000`.
3. Aus `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten Kandidaten mit `DISCOVER_OFFICIAL_WEBSITE`, `VERIFY_OFFICIAL_SITE` oder `MANUAL_DECISION` ermitteln.
4. Nur Kandidaten mit offizieller Firmenwebsite plus offizieller Karriere-/Jobs-/ATS-Evidenz in eine neue Welle `data/jobagent/company-discovery.official.wave-t-YYYYMMDD.json` aufnehmen.
5. Vor Import alle `official_website_url`, `career_url` und `discovery_url` per `Invoke-WebRequest` pruefen; unsichere oder nur sekundaer belegte Kandidaten fail-closed in Review belassen.
6. Import mit `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <wave-file> -WaveId B` ausfuehren.
7. Danach `Verify-JobAgentCompanyCandidates.ps1`, `Measure-JobAgentCompanyCoverage.ps1`, `Measure-JobAgentSourceCoverage.ps1` und die funktionsbezogenen Tests fuer Coverage, Candidate Verification, Import Waves, Report, HTML Audit, Viewport Audit, Source Verification, Source Adapters und Live Scan ausfuehren.
8. Roadmap/Todo/Handoff syncen; `supertest` nur laufen lassen, wenn Roadmap-Punkt abgeschlossen ist oder explizit angefragt wird.
