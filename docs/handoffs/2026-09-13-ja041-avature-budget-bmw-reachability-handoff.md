# JA-041 Handoff: Avature-Budget und BMW-Erreichbarkeit

Stand: 2026-09-13T03:09:47+02:00

## Ergebnis

- Siemens Energy/Avature ist mit breitem Budget nicht mehr `PARTIAL`.
- Kontrolllauf `logs/jobagent/daily-run-20260913T010421462Z.json`: `SUCCESS`, 1 Firma, 30 Raw-Jobs, 1 gepruefter Snapshot, 0 unsichere Quellen, 0 nicht erreichbare Quellen, 0 Fehler, 0 Zielrollentreffer.
- Verwendete Parameter: `-CompanyIds company:siemens_energy_ag -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 100 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto`.
- HTML-Evidence: `html/jobagent/daily-run-20260913T010421462Z.html`.

## BMW-Befund

- BMW Group bleibt nicht erreichbar: `logs/jobagent/daily-run-20260913T010245703Z.json` meldet `FAILED`, `NOT_REACHABLE`, Quelle `https://www.bmwgroup.jobs/de/en.html`.
- Adaptermeldung: `source_fetch_failed[HTTP_REQUEST_FAILED][curl.exe] ... curl: (92) HTTP/2 stream 1 was not closed cleanly: INTERNAL_ERROR ... JOBAGENT_STATUS:000`.
- Direkte Gegenprobe mit `curl.exe --http1.1` ergab lokal `SEC_E_NO_CREDENTIALS`; WSL-Fallback ist nicht nutzbar, weil `wsl.exe --list --quiet` keine Distribution ausgibt und `Ubuntu-22.04` nicht vorhanden ist.
- Das ist aktuell ein Fetch-/Umgebungs- oder Quellenzugangsproblem, kein belegter Jobparser-Erfolg.

## Verifikation

- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -CompanyIds company:siemens_energy_ag -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 100 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -CompanyIds company:bmw_group -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 30 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `1`, erwarteter dokumentierter Erreichbarkeitsfehler
- `cmd /c .\ci.cmd devserver-start` -> Exit `0`, vorhandener Listener auf `http://localhost:8500/` wiederverwendet
- `Test-NetConnection localhost -Port 9000` -> `TcpTestSucceeded=True`
- `Test-NetConnection localhost -Port 8090` -> `TcpTestSucceeded=False`; `ci.cmd devserver-start` nutzt projektspezifisch Port `8500`

## Naechster Schritt

BMW-spezifischen Fetch-/Fallback-Slice isolieren: entweder robuste Behandlung von BMWs HTTP/2-/Schannel-Verhalten implementieren oder eine belegte alternative offizielle BMW-Karriere-/ATS-Quelle im Store verifizieren. Danach breitere JA-041-Abschlussstichprobe laufen lassen.
