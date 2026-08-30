# Handoff latest

Stand: 2026-08-30T08:16:00.000+02:00

## Neuer-Chat-Status

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027`
- Status: `in-progress`
- Roadmap-Rotation: keine Rotation; `JA-027` ist nicht komplett erledigt.
- Supertest: nicht ausgefuehrt; laut Nutzeranweisung erst bei abgeschlossenem Roadmap-Punkt.
- SonarQube: `UP` auf `http://localhost:9000`
- Devserver: laeuft im Hintergrund auf `http://localhost:8500/`, PID `23568`

## Fachlicher Stand

`JA-027` erweitert den produktiven Store nur um Arbeitgeber, deren offizielle Firmenwebsite plus Karriere-/Jobs- oder offiziell verlinkte ATS-Quelle fail-closed belegt ist. Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints und duerfen nicht als produktiver Karrierebeleg verwendet werden.

Bis Welle N/B sind produktiv im Store:

- `195` Firmen
- `191` JobSources
- `193` offizielle Quellen in Source Coverage
- `192` Karrierequellen in Source Coverage
- Kandidatenqueue: `304` verifizierte/store-aware Kandidaten, `1478` DISCOVER_OFFICIAL_WEBSITE-Faelle, `2` VERIFY_OFFICIAL_SITE-Faelle, `1` MANUAL_DECISION

## Letzter abgeschlossener Arbeitsschritt

Welle N/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

1. EGYM DACH
2. Elgato
3. Dynamic Biosensors GmbH
4. European Space Imaging
5. Boku
6. CUPONATION
7. Faktor Zehn
8. Fernride
9. Behnisch Architekten
10. bogevischs buero
11. dtv Verlagsgesellschaft
12. Fleetster

Importwellen-Gate B: `passed`

Gate-Metriken:

- `coverage_delta=12`
- `duplicate_rate=0.0`
- `manual_review_rate=0.0`

All Nippon Airways wurde in der Kandidatenverifikation fail-closed nicht produktiv uebernommen, weil kein offiziell belegter Karriere- oder ATS-Link gefunden wurde.

## Wichtige Artefakte

- Welle-N-Feed: `data/jobagent/company-discovery.official.wave-n-20260830.json`
- Store: `data/jobagent/store.json`
- Kandidatenqueue: `data/jobagent/company-candidate-verification.queue.json`
- Importlog: `logs/jobagent/company-discovery-import-20260830-061136.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260830-061145.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260830-061146.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260830-061146.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260830T061137339Z-pre-wave-import.json`
- Viewport-Audit: `html/jobagent/ja-022-viewport-audit.html`

## Verifikation der Welle N/B

Alle folgenden Befehle liefen mit Exit `0`:

```powershell
Get-Content -Raw data\jobagent\company-discovery.official.wave-n-20260830.json | ConvertFrom-Json -Depth 100
Invoke-WebRequest -Method Get fuer alle official_website_url/career_url/discovery_url aus Welle N
pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-n-20260830.json -WaveId B
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxCandidates 1 -TimeoutSeconds 5
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent -MaxPriorityItems 250
pwsh -NoProfile -File .\tools\Measure-JobAgentSourceCoverage.ps1 -ProjectRoot D:\_Scripte\JobAgent
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
.\ci.cmd route-check
.\ci.cmd stp
.\ci.cmd devserver-status
Invoke-RestMethod -Uri http://localhost:9000/api/system/status -TimeoutSec 5
```

## Aufgaben fuer den naechsten Chat

1. `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `todo.checkpoint.json`, `handoff.latest.md` und `handoff.latest.json` lesen.
2. `git -c core.pager=cat -c color.ui=false --no-pager status --short --branch` ausfuehren und fremde Aenderungen nicht ueberschreiben.
3. In `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten `DISCOVER_OFFICIAL_WEBSITE`- und `VERIFY_OFFICIAL_SITE`-Eintraege fail-closed pruefen.
4. Synthetische Register-Sample-Namen wie `Alpha Technik GmbH`, `Beta Analytics AG`, `Gamma Logistics GmbH` und `Epsilon Alt GmbH` nicht produktiv aufnehmen, solange keine belastbare offizielle Website-/Karriere-Evidenz vorliegt.
5. Fuer Welle O nur Kandidaten aufnehmen, bei denen offizielle Firmenwebsite und Karriere-/Jobs-/ATS-Beleg nachvollziehbar sind.
6. Neuen Feed nach Muster `data/jobagent/company-discovery.official.wave-o-20260830.json` oder mit aktuellem Datum erstellen.
7. Import ausfuehren mit `tools\Import-JobAgentCompanyDiscovery.ps1 -WaveId B`, danach Queue, Coverage, Source Coverage und die funktionsbezogenen JA-027-Tests ausfuehren.
8. `Roadmap.md`, Todo-State, Handoff und STP synchronisieren. `JA-027` erst aus `Roadmap.md` rotieren, wenn die definierte Gesamtanforderung abgeschlossen ist.

## Risiken und Regeln

- Keine erfundenen Firmen, URLs, Job-IDs, Stellen, Geodaten oder Verifikationsaussagen.
- Keine produktive Firma ohne offiziellen finalen URL-Nachweis.
- Keine Nutzung von Jobboersen-, Arbeitsagentur- oder Register-URLs als offizielle Karrierequelle.
- PowerShell-HTTP-Checks koennen bei einzelnen offiziellen Karriereseiten blockiert werden; in solchen Faellen nur mit belastbarer offizieller Linkkette weiterarbeiten, sonst fail-closed in Review lassen.
- Dedupe ueber Domains kann Tochter-/Konzernfirmen zusammenfuehren; bei notwendiger fachlicher Trennung zuerst Dedupe-Strategie anpassen und testen.
