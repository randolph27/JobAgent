# JA-041 Handoff: BMW-HTTP/1.1-Fallback und Quellenkorrektur

Stand: 2026-09-13T09:28:00+02:00

## Ergebnis

- BMW-Quelle produktiv von `https://www.bmwgroup.jobs/de/en.html` auf die offiziell belegte und lokal abrufbare BMW-Group-Jobs-Subdomain `https://jobs.bmwgroup.com/` korrigiert.
- Die alte `bmwgroup.jobs`-URL bleibt im Discovery-/URL-Bestand erhalten; nur die aktuelle produktive Scan-Quelle wurde ersetzt.
- Curl-Fehler `curl: (92)`/unsaubere HTTP/2-Streams werden als `HTTP2_STREAM_FAILED` klassifiziert und mit `--http1.1` wiederholt.
- Kaputte Fremd-Hrefs wie `http://www.sec.gov.&nbsp` werden im Live-Parser uebersprungen und brechen den Firmenlauf nicht mehr ab.

## Evidence

- BMW-Kontrolllauf: `logs/jobagent/daily-run-20260913T073511041Z.json`
- BMW-HTML-Report: `html/jobagent/daily-run-20260913T073511041Z.html`
- Breitere Stichprobe: `logs/jobagent/daily-run-20260913T073648578Z.json`
- Breiter HTML-Report: `html/jobagent/daily-run-20260913T073648578Z.html`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -CompanyIds company:bmw_group -MaxCompanies 1 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 30 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `0`, `SUCCESS`, 4 Raw-Jobs, 4 Snapshots, 0 Fehler
- `pwsh -NoProfile -File .\tools\Invoke-JobAgentDailyRun.ps1 -MaxCompanies 10 -MaxResultsPerSource 100 -MaxDetailFetchesPerSource 100 -MaxPagesPerSource 30 -MaxRetries 0 -TimeoutSeconds 30 -FetchClient auto` -> Exit `0`, `PARTIAL`, 10 Firmen, 0 nicht erreichbare Quellen, 0 Fehler, Folgehotspot `company:msg_systems_ag` mit `NO_JOBS_FOUND`/`MANUAL_REVIEW`

## Naechster Anker

JA-041 bleibt offen. Naechster Hotspot ist `company:msg_systems_ag`: Die aktuelle breite Stichprobe liefert `PARTIAL`/`NO_JOBS_FOUND`/`MANUAL_REVIEW`, obwohl 9 von 10 Firmen vollstaendig `SUCCESS` ohne Treffer liefen. MSG-Quelle und Adapterverhalten muessen scan-lokal geprueft und danach in einer erneuten breiteren Stichprobe verifiziert werden.



