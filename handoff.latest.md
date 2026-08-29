# Handoff latest

Stand: 2026-08-29T08:08:02.127+02:00

## Zustand fuer neuen Chat

- Active: `TD-0041`
- Roadmap: `JA-027` bleibt offen; kein Roadmap-Punkt wurde rotiert, weil die Kandidatenbasis noch nicht vollstaendig abgearbeitet ist.
- Ziel: Weitere Arbeitgeber aus der Review-/Discovery-Queue duerfen erst produktiv in `data/jobagent/store.json`, wenn offizielle Firmenwebsite plus Karriere-/Jobs-/ATS-Beleg fail-closed verifiziert ist.
- Branch: `master`
- HEAD vor STP-Sync-Commit: `db1894574c83`
- Upstream: `origin/master`
- Ahead/Behind vor STP-Sync-Commit: `1/0`
- Route: `True`
- SonarQube: `UP` auf `http://localhost:9000`
- Devserver: laeuft auf `http://localhost:8500/`

## Abgeschlossener Arbeitsschritt

Welle H/B wurde umgesetzt, per Funktionstests verifiziert und mit STP synchronisiert. Der Code-Commit dazu ist `db18945 JA-027 import wave H verified employers`.

Verarbeitet wurden 8 offiziell belegte Arbeitgeber.

Neu produktiv aufgenommen wurden 7 Arbeitgeber:

- MGH - Muenchener Gewerbehof- und Technologiegesellschaft
- TUM School of Life Sciences
- Zentrum Wald-Forst-Holz Weihenstephan
- 36ZERO Vision GmbH
- 4.screen GmbH
- AES Aerospace Embedded Solutions GmbH
- Aesir Interactive GmbH

Dedupliziertes Update:

- Deutsche Telekom Technik GmbH wurde wegen `domain:telekom.com` als Update zu Deutsche Telekom AG zusammengefuehrt. Im Store existiert damit aktuell kein separater Telekom-Technik-Datensatz.

Ergaenzte Implementierung:

- `src/JobAgent.SourceVerification.psm1` erkennt jetzt offiziell verlinkte Workable-Portale als ATS-Bindung.
- `tests/Test-JobAgentSourceVerification.ps1` enthaelt einen Workable-ATS-Funktionstest mit offizieller Firmenlink-Evidenz.

## Kennzahlen

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

Supertest wurde nicht frisch ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt, wenn er nicht explizit angefragt wurde. `.\ci.cmd stp` verweist weiterhin auf den letzten erfolgreichen Supertest-Digest.

## Naechste Aufgabe

1. In `data/jobagent/company-candidate-verification.queue.json` die hoechstpriorisierten `DISCOVER_OFFICIAL_WEBSITE`-Kandidaten weiter abarbeiten.
2. Synthetische Register-Sample-Namen wie `Alpha Technik GmbH`, `Beta Analytics AG`, `Gamma Logistics GmbH` und `Epsilon Alt GmbH` nur bei belastbarer offizieller Website-Evidenz aufnehmen; sonst fail-closed in Review belassen.
3. Weitere regionale/Tech-Kandidaten priorisieren, aber nur mit offizieller Firmenwebsite plus Karriere-/Jobs- oder offiziell verlinktem ATS-Beleg in eine neue Welle uebernehmen.
4. Neuen Wave-Feed nach Muster `data/jobagent/company-discovery.official.wave-<letter>-<date>.json` erstellen.
5. Import ausfuehren:

```powershell
pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <feed> -WaveId B
```

6. Danach Queue, Coverage, Source Coverage und die funktionsbezogenen JA-027-Tests erneut ausfuehren.
7. `Roadmap.md`, Todo und Handoff synchronisieren; JA-027 erst rotieren, wenn die definierte Verifikations-/Importwellen-Anforderung insgesamt abgeschlossen ist.

## Risiken und Annahmen

- Viele restliche Kandidaten sind nur regionale Hints ohne belastbare Firmenwebsite; fail-closed in Review lassen.
- Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints, nicht produktive Karrierebelege.
- Externe ATS-Portale nur akzeptieren, wenn sie von der offiziellen Firmenwebsite belegbar sind.
- Dedupe ueber Domains kann Tochter-/Konzernfirmen zusammenfuehren; bei fachlich notwendiger Trennung muss vorher die Dedupe-Strategie angepasst und getestet werden.
