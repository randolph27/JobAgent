# Handoff JA-027.3 Website-Reaktivierung und Teilbenchmark

Stand: 2026-09-07 13:23 Europe/Berlin

## Aktiver Punkt

- Todo: `TD-0041`
- Roadmap: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`
- Keine Roadmap-Rotation: echter 100-Kandidaten-Live-Benchmark und 1.000 belegte Karriere-/ATS-Quellen fehlen weiter.

## Erledigter Arbeitsschritt

Die Queue kann `MANUAL_REVIEW_REQUIRED`-Eintraege wieder in `PENDING/VERIFY_OFFICIAL_SITE` ueberfuehren, wenn spaeter eine belastbare Domain/Website-Evidence am Kandidaten vorliegt. Website-Ermittlung terminiert Abruffehler jetzt als `RETRY_SCHEDULED` mit `next_attempt_at`, statt sie dauerhaft als Manual-Review zu blockieren. Fehlerhafte Hrefs auf Quellseiten werden beim Linkscan uebersprungen und brechen die Kandidatenverarbeitung nicht mehr ab.

Live-Nachfuellung:

```powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
```

Ergebnis:

- `logs/jobagent/company-candidate-website-discovery-20260907-111545.json`
- verarbeitet: 42
- offizielle Websites belegt: 18
- Manual-Review: 10
- Retry: 14

Anschliessender Teilbenchmark:

```powershell
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
```

Ergebnis:

- `logs/jobagent/JA-027-batch-20260907-111932.json`
- `logs/jobagent/JA-027-resume-20260907-111932.json`
- verarbeitet: 17
- produktive Upserts: 8 neue `COMPANY_DOMAIN_VERIFIED`-Firmen
- Requests: 52
- P50/P95: 1403 ms / 3677 ms
- Nettozuwachs offizieller Karriere-/ATS-Arbeitgeber: 0
- Store nach Coverage-Refresh: 487 Firmen, 439 JobSources
- Queue nach Coverage-Refresh: 675 `VERIFIED`, 23 `RETRY_SCHEDULED`, 1.132 `MANUAL_REVIEW_REQUIRED`, 0 `PENDING`

## Geaenderte Dateien

- `src/JobAgent.Coverage.psm1`
- `src/JobAgent.SourceVerification.psm1`
- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1`
- `tests/Test-JobAgentCoverage.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-candidate-verification.checkpoint.json`
- `data/jobagent/company-candidate-verification.checkpoint.json.results/`
- `data/jobagent/store.json`
- `html/jobagent/company-coverage.html`
- `Roadmap.md`

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot . -MaxPriorityItems 10
```

Alle vier Befehle liefen mit Exit `0`.

## Naechster Anker

JA-027.3 braucht weitere faellige Kandidaten. Aktuell gibt es 0 `PENDING`; 23 Eintraege sind fuer spaetere Retry-Zeitpunkte geplant. Naechster sinnvoller Schnitt: zulaessige Quellen mit Website-/Karrierehinweisen nachfuellen oder die 1.132 Manual-Review-Faelle gezielt nach belegbarer offizieller Evidence segmentieren. Danach erst erneut `Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 100` als echten 100er-Benchmark ausfuehren.
