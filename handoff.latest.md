# Handoff latest

Stand: 2026-08-29T12:54:37.378+02:00

## Zustand fuer neuen Chat

- Active: `TD-0041`
- Roadmap: `JA-027` bleibt offen; Welle J/B ist abgeschlossen, die Gesamtanforderung zur vollstaendigen Kandidatenabarbeitung aber noch nicht.
- Ziel: Weitere Arbeitgeber aus der Review-/Discovery-Queue duerfen erst produktiv in `data/jobagent/store.json`, wenn offizielle Firmenwebsite plus Karriere-/Jobs-/ATS-Beleg fail-closed verifiziert ist.
- Branch: `master`
- HEAD vor neuem Abschluss-Commit: `1ce2b4a99059`
- Upstream: `origin/master`
- Ahead/Behind vor Push: `1/0`
- Route: `True`
- SonarQube: `UP` auf `http://localhost:9000`
- Devserver: laeuft auf `http://localhost:8500/`

## Abgeschlossener Arbeitsschritt

Welle J/B wurde umgesetzt, per Funktionstests verifiziert und per STP synchronisiert.

Neu produktiv aufgenommen wurden 12 Arbeitgeber:

- Power Factors GmbH
- Aboalarm GmbH
- Actyx AG
- allmannwappner gmbh
- Apple GmbH
- Atos Information Technology GmbH
- Bain & Company Germany Inc.
- Bavaria Film GmbH
- Bertrandt Technology Consulting GmbH
- Biogen GmbH
- Blickfeld GmbH
- Bayerische Landeszentrale fuer neue Medien

## Kennzahlen nach Welle J/B

- Store: `151` Firmen, `147` JobSources
- Source Coverage: `1969` Quellen gesamt, `149` offizielle Quellen, `148` Karrierequellen
- Kandidatenqueue: `247` verifizierte/store-aware Kandidaten, `1537` manuelle Reviewfaelle, `1` Retry
- Importwellen-Gate B: `passed`
- Gate-Metriken: `coverage_delta=12`, `duplicate_rate=0.0`, `manual_review_rate=0.0`
- Store-Backup: `data/jobagent/backups/store-20260829T104735336Z-pre-wave-import.json`

## Wichtige Artefakte

- Feed: `data/jobagent/company-discovery.official.wave-j-20260829.json`
- Importlog: `logs/jobagent/company-discovery-import-20260829-104734.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260829-104742.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260829-104743.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260829-104743.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`
- Viewport-Audit: `logs/jobagent/ja-022-viewport-audit.md`

## Verifikation

- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-j-20260829.json -WaveId B` -> Exit `0`
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

Supertest wurde nicht frisch ausgefuehrt; laut Nutzeranweisung gilt er als erledigt, wenn er nicht angefragt wurde.

## Naechste Aufgabe

1. In `data/jobagent/company-candidate-verification.queue.json` die hoechstpriorisierten `DISCOVER_OFFICIAL_WEBSITE`-Kandidaten weiter abarbeiten.
2. Synthetische Register-Sample-Namen wie `Alpha Technik GmbH`, `Beta Analytics AG`, `Gamma Logistics GmbH` und `Epsilon Alt GmbH` nur bei belastbarer offizieller Website-Evidenz aufnehmen; sonst fail-closed in Review belassen.
3. Weitere regionale/Tech-Kandidaten priorisieren, aber nur mit offizieller Firmenwebsite plus Karriere-/Jobs- oder offiziell verlinktem ATS-Beleg in eine neue Welle uebernehmen.
4. Neuen Wave-Feed nach Muster `data/jobagent/company-discovery.official.wave-<letter>-<date>.json` erstellen.
5. Import, Queue, Coverage, Source Coverage und die funktionsbezogenen JA-027-Tests erneut ausfuehren.
6. `Roadmap.md`, Todo und Handoff synchronisieren; JA-027 erst rotieren, wenn die definierte Verifikations-/Importwellen-Anforderung insgesamt abgeschlossen ist.

## Risiken und Annahmen

- Viele restliche Kandidaten sind nur regionale Hints ohne belastbare Firmenwebsite; fail-closed in Review lassen.
- Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints, nicht produktive Karrierebelege.
- Externe ATS-Portale nur akzeptieren, wenn sie von der offiziellen Firmenwebsite belegbar sind.
- Dedupe ueber Domains kann Tochter-/Konzernfirmen zusammenfuehren; bei fachlich notwendiger Trennung muss vorher die Dedupe-Strategie angepasst und getestet werden.
