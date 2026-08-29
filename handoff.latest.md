# Handoff latest

Stand: 2026-08-29T07:55:00.000+02:00

## Zustand fuer neuen Chat

- Active: `TD-0041`
- Roadmap: `JA-027` bleibt offen, weil die Kandidatenbasis noch nicht vollstaendig abgearbeitet ist.
- Ziel: Weitere Arbeitgeber aus der Review-/Discovery-Queue duerfen erst produktiv in `data/jobagent/store.json`, wenn offizielle Firmenwebsite plus Karriere-/Jobs-/ATS-Beleg fail-closed verifiziert ist.
- Branch: `master`
- HEAD vor Abschlusscommit: `43af5aaa0997`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Route: `True`
- SonarQube: `UP` auf `http://localhost:9000`
- Devserver: laeuft auf `http://localhost:8500/`

## Abgeschlossener Slice

Welle G/B wurde als produktive Importwelle abgeschlossen. Neu aufgenommen wurden 9 offiziell belegte Arbeitgeber:

- Innovations- und Gruenderzentrum Biotechnologie Weihenstephan
- Amgen GmbH
- Arthrex GmbH
- Brainlab AG
- Bio-Rad Laboratories GmbH
- Baxter Deutschland GmbH
- Bristol Myers Squibb GmbH & Co. KGaA
- Bavarian Nordic GmbH
- bene-Arzneimittel GmbH

Kennzahlen nach Welle G/B:

- Store: `124` Firmen, `120` JobSources
- Source Coverage: `1942` Quellen gesamt, `122` offizielle Quellen, `121` Karrierequellen
- Kandidatenqueue: `207` verifizierte/store-aware Kandidaten, `1577` manuelle Reviewfaelle
- Importwellen-Gate B: `passed`
- Gate-Metriken: `coverage_delta=9`, `duplicate_rate=0.0`, `manual_review_rate=0.0`
- Store-Backup: `data/jobagent/backups/store-20260829T054757808Z-pre-wave-import.json`

## Wichtige Artefakte

- Feed: `data/jobagent/company-discovery.official.wave-g-20260829.json`
- Importlog: `logs/jobagent/company-discovery-import-20260829-054757.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260829-054805.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260829-054805.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260829-054805.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`

## Verifikation

- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-g-20260829.json -WaveId B` -> Exit `0`
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

Supertest wurde fuer diesen Slice nicht frisch ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt, da nicht angefragt. `.\ci.cmd stp` hat automatisch den letzten gespeicherten Verify-Digest (`.\ci.cmd supertest`) in die CAPSULE geschrieben.

## Naechste Aufgabe

1. In `data/jobagent/company-candidate-verification.queue.json` die hoechstpriorisierten `DISCOVER_OFFICIAL_WEBSITE`-Kandidaten weiter abarbeiten.
2. Nur offizielle Firmen-/Karriere-/ATS-Belege als neuen Wave-Feed nach Muster `data/jobagent/company-discovery.official.wave-<letter>-<date>.json` erfassen.
3. Danach Import mit `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath <feed> -WaveId B`.
4. Anschliessend Queue, Coverage, Source Coverage und die funktionsbezogenen Tests aus JA-027 ausfuehren.
5. `Roadmap.md`, Todo und Handoff synchronisieren; JA-027 erst rotieren, wenn die definierte Verifikations-/Importwellen-Anforderung insgesamt abgeschlossen ist.

## Risiken und Annahmen

- Viele restliche Kandidaten sind nur regionale Hints ohne belastbare Firmenwebsite; fail-closed in Review lassen.
- Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints, nicht produktive Karrierebelege.
- Externe ATS-Portale nur akzeptieren, wenn sie von der offiziellen Firmenwebsite belegbar sind.
- Keine automatische Bewerbung und keine extern wirksame Aktion ohne ausdrueckliche Bestaetigung.
