# Handoff latest

Stand: 2026-08-30T08:46:37.116+02:00

## Neuer-Chat-Status

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- HEAD: `2b127ec1ab3a`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027`
- Status: `in-progress`
- Roadmap-Rotation: keine Rotation; `JA-027` bleibt offen, weil noch `1443` Kandidaten in `DISCOVER_OFFICIAL_WEBSITE`, `2` Kandidaten in `VERIFY_OFFICIAL_SITE` und `1` Kandidat in `MANUAL_DECISION` stehen.
- Supertest: nicht erneut angefragt und gemaess Nutzeranweisung fuer diesen Abschluss als erledigt gewertet; JA-027 bleibt insgesamt offen.
- SonarQube: `UP` auf `http://localhost:9000`
- Devserver: laeuft im Hintergrund auf `http://localhost:8500/`, PID `23568`

## Fachlicher Stand

`JA-027` erweitert den produktiven Store nur um Arbeitgeber, deren offizielle Firmenwebsite plus Karriere-/Jobs- oder offiziell verlinkte ATS-Quelle fail-closed belegt ist. Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints und duerfen nicht als produktiver Karrierebeleg verwendet werden.

Bis Welle P/B sind produktiv im Store:

- `218` Firmen
- `214` JobSources
- `216` offizielle Quellen in Source Coverage
- `215` Karrierequellen in Source Coverage
- Kandidatenqueue: `339` verifizierte/store-aware Kandidaten, `1443` DISCOVER_OFFICIAL_WEBSITE-Faelle, `2` VERIFY_OFFICIAL_SITE-Faelle, `1` MANUAL_DECISION

## Letzter abgeschlossener Arbeitsschritt

Welle P/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

1. Delightex GmbH
2. Ebenbuild
3. Emax Digital
4. E.ON
5. DHL Delivery
6. Continental Automotive
7. Alphabet
8. Amazon Web Services
9. Bayerische Versicherungsgesellschaft
10. BMW Car IT
11. Differential Bio

Bayerische Versicherungskammer wurde wegen `name:versicherungskammer bayern` als Update zu Versicherungskammer Bayern dedupliziert.

Importwellen-Gate B: `passed`

Gate-Metriken:

- `coverage_delta=11`
- `duplicate_rate=0.0833`
- `manual_review_rate=0.0`

All Nippon Airways wurde erneut fail-closed nicht produktiv uebernommen und bleibt `RETRY_EXHAUSTED`, weil kein offiziell belegter Karriere- oder ATS-Link gefunden wurde.

## Wichtige Artefakte

- Welle-P-Feed: `data/jobagent/company-discovery.official.wave-p-20260830.json`
- Store: `data/jobagent/store.json`
- Kandidatenqueue: `data/jobagent/company-candidate-verification.queue.json`
- Importlog: `logs/jobagent/company-discovery-import-20260830-064125.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260830-064130.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260830-064214.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260830-064214.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260830T064125984Z-pre-wave-import.json`
- Viewport-Audit: `html/jobagent/ja-022-viewport-audit.html`

## Verifikation der Welle P/B

Alle folgenden Befehle liefen mit Exit `0`:

```powershell
Get-Content -Raw data\jobagent\company-discovery.official.wave-p-20260830.json | ConvertFrom-Json -Depth 100
Invoke-WebRequest -Method Get fuer alle official_website_url/career_url/discovery_url aus Welle P
pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-p-20260830.json -WaveId B
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
5. Fuer Welle Q nur Kandidaten aufnehmen, bei denen offizielle Firmenwebsite und Karriere-/Jobs-/ATS-Beleg nachvollziehbar sind.
6. Neuen Feed nach Muster `data/jobagent/company-discovery.official.wave-q-20260830.json` oder mit aktuellem Datum erstellen.
7. Import ausfuehren mit `tools\Import-JobAgentCompanyDiscovery.ps1 -WaveId B`, danach Queue, Coverage, Source Coverage und die funktionsbezogenen JA-027-Tests ausfuehren.
8. `Roadmap.md`, Todo-State, Handoff und STP synchronisieren. `JA-027` erst aus `Roadmap.md` rotieren, wenn die definierte Gesamtanforderung abgeschlossen ist.

## Risiken und Regeln

- Keine erfundenen Firmen, URLs, Job-IDs, Stellen, Geodaten oder Verifikationsaussagen.
- Keine produktive Firma ohne offiziellen finalen URL-Nachweis.
- Keine Nutzung von Jobboersen-, Arbeitsagentur- oder Register-URLs als offizielle Karrierequelle.
- PowerShell-HTTP-Checks koennen bei einzelnen offiziellen Karriereseiten blockiert werden; in solchen Faellen nur mit belastbarer offizieller Linkkette weiterarbeiten, sonst fail-closed in Review lassen.
- Dedupe ueber Domains kann Tochter-/Konzernfirmen zusammenfuehren; bei notwendiger fachlicher Trennung zuerst Dedupe-Strategie anpassen und testen.
