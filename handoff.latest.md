# Handoff latest

Stand: 2026-08-29T13:24:00.000+02:00

## Neuer-Chat-Status

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027`
- Status: `in-progress`
- Roadmap-Rotation: keine Rotation; `JA-027` ist nicht komplett erledigt.
- Supertest: nicht ausgefuehrt; laut Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.
- SonarQube: zuletzt `UP` auf `http://localhost:9000`
- Devserver: fuer Viewport-Audit erreichbar auf `http://127.0.0.1:8500/`

## Fachlicher Stand

`JA-027` erweitert den produktiven Store nur um Arbeitgeber, deren offizielle Firmenwebsite plus Karriere-/Jobs- oder offiziell verlinkte ATS-Quelle fail-closed belegt ist. Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints und duerfen nicht als produktiver Karrierebeleg verwendet werden.

Bis Welle L/B sind produktiv im Store:

- `171` Firmen
- `167` JobSources
- `169` offizielle Quellen in Source Coverage
- `168` Karrierequellen in Source Coverage
- Kandidatenqueue: `273` verifizierte/store-aware Kandidaten, `1509` DISCOVER_OFFICIAL_WEBSITE-Faelle, `2` VERIFY_OFFICIAL_SITE-Faelle, `1` MANUAL_DECISION

## Letzter abgeschlossener Arbeitsschritt

Welle L/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

1. ANGSA Robotics GmbH
2. deepc GmbH
3. DACHSER SE
4. Augustiner-Braeu Wagner KG
5. Droemer Knaur GmbH & Co. KG
6. Dassault Systemes Deutschland GmbH
7. Bayerische Landesbodenkreditanstalt
8. Deloitte GmbH

Importwellen-Gate B: `passed`

Gate-Metriken:

- `coverage_delta=8`
- `duplicate_rate=0.0`
- `manual_review_rate=0.0`

## Wichtige Artefakte

- Welle-L-Feed: `data/jobagent/company-discovery.official.wave-l-20260829.json`
- Store: `data/jobagent/store.json`
- Kandidatenqueue: `data/jobagent/company-candidate-verification.queue.json`
- Importlog: `logs/jobagent/company-discovery-import-20260829-111453.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260829-111502.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260829-111502.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260829-111502.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260829T111454226Z-pre-wave-import.json`
- Viewport-Audit: `html/jobagent/ja-022-viewport-audit.html`

## Verifikation der Welle L/B

Alle folgenden Befehle liefen mit Exit `0`:

```powershell
pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-l-20260829.json -WaveId B
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
```

Zusaetzlicher URL-Check: alle `official_website_url`, `career_url` und `discovery_url` aus dem Welle-L-Feed antworteten per `Invoke-WebRequest -Method Head` mit HTTP `200`.

## Aufgaben fuer den naechsten Chat

1. `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `todo.checkpoint.json`, `handoff.latest.md` und `handoff.latest.json` lesen.
2. `git -c core.pager=cat -c color.ui=false --no-pager status --short --branch` ausfuehren und fremde Aenderungen nicht ueberschreiben.
3. In `data/jobagent/company-candidate-verification.queue.json` die naechsten priorisierten `DISCOVER_OFFICIAL_WEBSITE`- und `VERIFY_OFFICIAL_SITE`-Eintraege fail-closed pruefen.
4. Synthetische Register-Sample-Namen wie `Alpha Technik GmbH`, `Beta Analytics AG`, `Gamma Logistics GmbH` und `Epsilon Alt GmbH` nicht produktiv aufnehmen, solange keine belastbare offizielle Website-/Karriere-Evidenz vorliegt.
5. Fuer Welle M nur Kandidaten aufnehmen, bei denen offizielle Firmenwebsite und Karriere-/Jobs-/ATS-Beleg nachvollziehbar sind.
6. Neuen Feed nach Muster `data/jobagent/company-discovery.official.wave-m-20260829.json` oder mit aktuellem Datum erstellen.
7. Import ausfuehren mit `tools\Import-JobAgentCompanyDiscovery.ps1 -WaveId B`, danach Queue, Coverage, Source Coverage und die funktionsbezogenen JA-027-Tests ausfuehren.
8. `Roadmap.md`, Todo-State, Handoff und STP synchronisieren. `JA-027` erst aus `Roadmap.md` rotieren, wenn die definierte Gesamtanforderung abgeschlossen ist.

## Risiken und Regeln

- Keine erfundenen Firmen, URLs, Job-IDs, Stellen, Geodaten oder Verifikationsaussagen.
- Keine produktive Firma ohne offiziellen finalen URL-Nachweis.
- Keine Nutzung von Jobboersen-, Arbeitsagentur- oder Register-URLs als offizielle Karrierequelle.
- PowerShell-HTTP-Checks koennen bei einzelnen offiziellen Karriereseiten blockiert werden; in solchen Faellen nur mit belastbarer offizieller Linkkette weiterarbeiten, sonst fail-closed in Review lassen.
- Dedupe ueber Domains kann Tochter-/Konzernfirmen zusammenfuehren; bei notwendiger fachlicher Trennung zuerst Dedupe-Strategie anpassen und testen.
