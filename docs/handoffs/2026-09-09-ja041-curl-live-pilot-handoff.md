# JA-041 Handoff: Curl-Live-Pilot

Stand: 2026-09-09T13:15:00+02:00

## Ziel

JA-041 bleibt `in-progress`. Dieser Slice beseitigt den lokalen HTTPS-Blocker fuer den Curl-Fetchpfad und belegt wieder einen erfolgreichen produktiven Live-Pilot gegen eine offizielle Karriereseite.

## Aenderungen

- `src/JobAgent.SourceVerification.psm1`
  - bevorzugt fuer `FetchClient curl` ein nicht-Schannel-`curl.exe`, wenn mehrere `curl.exe` im PATH liegen.
  - erkennt OpenSSL-/LibreSSL-/BoringSSL-kompatible Curl-Builds und setzt dann `--ca-native`.
  - dokumentiert Curl-Pfad, TLS-Backend und CA-Native-Nutzung im Fetchresultat.
  - behaelt den vorhandenen Schannel-Fallbackpfad mit dokumentierter `tls_revocation_policy`.
- `tests/Test-JobAgentSourceVerification.ps1`
  - prueft Policy-Feld, Curl-TLS-Backend-Aufloesung, CA-Native-Entscheidung und Fallback-Metadaten.
- `data/jobagent/store.json`
  - enthaelt den erfolgreichen Live-Scan `scanrun:20260909T110550035Z` mit 10 Snapshots.

## Live-Evidence

```powershell
pwsh -NoProfile -File .\tools\Invoke-JobAgentLivePilot.ps1 -ProjectRoot . -MaxCompanies 1 -TimeoutSeconds 20 -MaxRetries 0 -MaxResultsPerSource 20 -MaxDetailFetchesPerSource 20 -MaxPagesPerSource 5 -FetchClient curl
```

Ergebnis:

- `logs/jobagent/daily-run-20260909T110550035Z.json`
- Status `SUCCESS`
- 1 Firma gescannt
- 10 Raw-Jobs
- 10 gepruefte Jobs
- 10 Snapshots
- 0 Fehler
- 0 aktive Zielrollentreffer
- HTML: `html/jobagent/daily-run-20260909T110550035Z.html`

Der vorherige Negativlauf `logs/jobagent/daily-run-20260909T110053094Z.json` bleibt als Diagnose erhalten: Windows-Schannel-`curl.exe` scheiterte mit `SEC_E_NO_CREDENTIALS`.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
```

Alle drei Funktionstests liefen erfolgreich. `.\ci.cmd supertest` wurde nicht ausgefuehrt, weil JA-041 noch offen ist.

## Naechster Schritt

Die 10 Snapshots aus `scanrun:20260909T110550035Z` fachlich auswerten: Zielrollen-/Standortklassifikation pruefen, dann einen kleinen Mehrfirmen-Live-Pilot starten und daraus die naechste ATS-/Parser-Erweiterung ableiten.
