# Handoff latest

Stand: 2026-08-29T08:05:39.569+02:00

## Zustand fuer neuen Chat

- Active: `TD-0041`
- Roadmap: `JA-027` bleibt offen, weil die Kandidatenbasis noch nicht vollstaendig abgearbeitet ist.
- Ziel: Weitere Arbeitgeber aus der Review-/Discovery-Queue duerfen erst produktiv in `data/jobagent/store.json`, wenn offizielle Firmenwebsite plus Karriere-/Jobs-/ATS-Beleg fail-closed verifiziert ist.
- Branch: `master`
- HEAD vor Abschlusscommit: `6da8c131e9ac`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Route: `True`
- SonarQube: `UP` auf `http://localhost:9000`
- Devserver: laeuft auf `http://localhost:8500/`

## Abgeschlossener Slice

Welle H/B wurde als produktive Importwelle abgeschlossen. Verarbeitet wurden 8 offiziell belegte Arbeitgeber.

Neu aufgenommen wurden 7 Arbeitgeber:

- MGH - Muenchener Gewerbehof- und Technologiegesellschaft
- TUM School of Life Sciences
- Zentrum Wald-Forst-Holz Weihenstephan
- 36ZERO Vision GmbH
- 4.screen GmbH
- AES Aerospace Embedded Solutions GmbH
- Aesir Interactive GmbH

Dedupliziertes Update:

- Deutsche Telekom Technik GmbH wurde wegen `domain:telekom.com` als Update zu Deutsche Telekom AG zusammengefuehrt.

Ergaenzte Implementierung:

- `src/JobAgent.SourceVerification.psm1` erkennt jetzt offiziell verlinkte Workable-Portale als ATS-Bindung.
- `tests/Test-JobAgentSourceVerification.ps1` deckt den Workable-ATS-Fall mit offizieller Firmenlink-Evidenz ab.

Kennzahlen nach Welle H/B:

- Store: `131` Firmen, `127` JobSources
- Source Coverage: `1949` Quellen gesamt, `129` offizielle Quellen, `128` Karrierequellen
- Kandidatenqueue: `216` verifizierte/store-aware Kandidaten, `1568` manuelle Reviewfaelle
- Importwellen-Gate B: `passed`
- Gate-Metriken: `coverage_delta=7`, `duplicate_rate=0.125`, `manual_review_rate=0.0`
- Store-Backup: `data/jobagent/backups/store-20260829T055943156Z-pre-wave-import.json`

## Wichtige Artefakte

- Feed: `data/jobagent/company-discovery.official.wave-h-20260829.json`
- Importlog: `logs/jobagent/company-discovery-import-20260829-055942.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260829-055950.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260829-055951.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260829-055951.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`
- Viewport-Audit: `logs/jobagent/ja-022-viewport-audit.md`

## Verifikation

- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-h-20260829.json -WaveId B` -> Exit `0`
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
- `Invoke-WebRequest http://localhost:9000/api/system/status` -> Exit `0`, Status `UP`
- `.\ci.cmd devserver-status` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

Supertest wurde fuer diesen Slice nicht frisch ausgefuehrt, weil JA-027 insgesamt offen bleibt.

## Naechste Aufgabe

1. In `data/jobagent/company-candidate-verification.queue.json` die hoechstpriorisierten `DISCOVER_OFFICIAL_WEBSITE`-Kandidaten weiter abarbeiten.
2. Synthetische Register-Sample-Namen wie `Alpha Technik GmbH`, `Beta Analytics AG`, `Gamma Logistics GmbH` und `Epsilon Alt GmbH` nur bei belastbarer offizieller Website-Evidenz aufnehmen; sonst fail-closed in Review belassen.
3. Nur offizielle Firmen-/Karriere-/ATS-Belege als neuen Wave-Feed nach Muster `data/jobagent/company-discovery.official.wave-<letter>-<date>.json` erfassen.
4. Danach Import mit `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <feed> -WaveId B`.
5. Anschliessend Queue, Coverage, Source Coverage und die funktionsbezogenen Tests aus JA-027 ausfuehren.
6. `Roadmap.md`, Todo und Handoff synchronisieren; JA-027 erst rotieren, wenn die definierte Verifikations-/Importwellen-Anforderung insgesamt abgeschlossen ist.

## Risiken und Annahmen

- Viele restliche Kandidaten sind nur regionale Hints ohne belastbare Firmenwebsite; fail-closed in Review lassen.
- Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints, nicht produktive Karrierebelege.
- Externe ATS-Portale nur akzeptieren, wenn sie von der offiziellen Firmenwebsite belegbar sind.
- Deutsche Telekom Technik GmbH ist im Store derzeit kein separater Arbeitgeberdatensatz, sondern ueber die bestehende Telekom-Domain mit Deutsche Telekom AG zusammengefuehrt.
