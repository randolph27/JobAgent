# Handoff JA-027.3 Host-Concurrency und Eligibility

Stand: 2026-09-07 09:05 Europe/Berlin

## Aktiver Punkt

- Todo: `TD-0041`
- Roadmap: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`
- Keine Roadmap-Rotation: echter 100-Kandidaten-Live-Benchmark, Kandidaten-Nachfuellung/Requeue und 1.000 belegte Karriere-/ATS-Quellen fehlen weiter.

## Erledigter Arbeitsschritt

`HostConcurrency` wird jetzt vom CLI bis in die HTTP-Policy transportiert. Live-Abrufe in `src/JobAgent.SourceVerification.psm1` folgen Redirects manuell und sperren jeden tatsaechlich abgerufenen Host ueber einen prozessweiten Semaphore. Damit fallen auch Redirect-/ATS-Ziele unter das Hostlimit, nicht nur die initiale Kandidatenauswahl.

Der vorbereitende 100er-Lauf wurde ausgefuehrt:

```powershell
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
```

Ergebnis:

- `logs/jobagent/JA-027-batch-20260907-065719.json`
- `logs/jobagent/JA-027-resume-20260907-065719.json`
- `ready_total=0`
- `processed_total=0`
- `request_total=0`
- `net_official_career_growth=0`
- Queue-Bestand: 667 `VERIFIED`, 1.163 `MANUAL_REVIEW_REQUIRED`, 1 `RETRY_EXHAUSTED`, 0 `PENDING`

Das ist kein erfolgreicher 100er-Benchmark, sondern ein belegter No-op wegen fehlender faelliger `PENDING`/`VERIFY_OFFICIAL_SITE`-Kandidaten.

## Geaenderte Dateien

- `src/JobAgent.SourceVerification.psm1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentSourceVerification.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `Roadmap.md`
- `docs/handoffs/2026-09-07-ja027-host-concurrency-eligibility-handoff.md`

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
```

Alle drei Funktionstests liefen mit Exit `0`.

## Naechster Anker

Vor einem weiteren 100er-Live-Lauf muessen mindestens 100 faellige Kandidaten erzeugt werden. Sinnvoller naechster Schnitt: `MANUAL_REVIEW_REQUIRED`-Eintraege mit offizieller Source-Evidence und vorhandenen/ermittelbaren Website-Hinweisen gezielt requeue-en oder durch `Discover-JobAgentCompanyCandidateWebsites.ps1` nachfuellen; danach erst den 100er-Benchmark erneut starten.
