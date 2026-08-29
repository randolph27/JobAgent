# Handoff latest

Stand: 2026-08-29T13:09:30.000+02:00

## Neuer-Chat-Status

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Aktiver Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027`
- Status: `in-progress`
- Roadmap-Rotation: keine Rotation; `JA-027` ist nicht komplett erledigt.
- Supertest: nicht erneut ausgefuehrt; laut Nutzeranweisung gilt er fuer diesen Abschluss als erledigt.
- SonarQube: zuletzt `UP` auf `http://localhost:9000`
- Devserver: zuletzt laufend auf `http://localhost:8500/`

## Fachlicher Stand

`JA-027` erweitert den produktiven Store nur um Arbeitgeber, deren offizielle Firmenwebsite plus Karriere-/Jobs- oder offiziell verlinkte ATS-Quelle fail-closed belegt ist. Jobboersen, Arbeitsagentur, Register und regionale Verzeichnisse bleiben Discovery-Hints und duerfen nicht als produktiver Karrierebeleg verwendet werden.

Bis Welle K/B sind produktiv im Store:

- `163` Firmen
- `159` JobSources
- `161` offizielle Quellen in Source Coverage
- `160` Karrierequellen in Source Coverage
- Kandidatenqueue: `263` verifizierte/store-aware Kandidaten, `1521` manuelle Reviewfaelle, `1` Retry

## Letzter abgeschlossener Arbeitsschritt

Welle K/B wurde abgeschlossen. Neu produktiv aufgenommen wurden:

1. Personio SE & Co. KG
2. PAYBACK GmbH
3. ParkDepot GmbH
4. parcelLab GmbH
5. OroraTech GmbH
6. Orbem GmbH
7. ottonova Holding AG
8. Workaround GmbH / ProGlove
9. Qualcomm Germany GmbH
10. PPRO Financial Ltd.
11. Regiondo GmbH
12. mgm technology partners GmbH

Importwellen-Gate B: `passed`

Gate-Metriken:

- `coverage_delta=12`
- `duplicate_rate=0.0`
- `manual_review_rate=0.0`

## Wichtige Artefakte

- Welle-K-Feed: `data/jobagent/company-discovery.official.wave-k-20260829.json`
- Store: `data/jobagent/store.json`
- Kandidatenqueue: `data/jobagent/company-candidate-verification.queue.json`
- Importlog: `logs/jobagent/company-discovery-import-20260829-110011.json`
- Queue-Log: `logs/jobagent/company-candidate-verification-20260829-110019.json`
- Coverage JSON: `logs/jobagent/company-coverage-20260829-110059.json`
- Coverage Markdown: `logs/jobagent/company-coverage-20260829-110059.md`
- Source Coverage: `logs/jobagent/ja-023-source-coverage.json`
- HTML Coverage: `html/jobagent/company-coverage.html`
- Store-Backup: `data/jobagent/backups/store-20260829T110012490Z-pre-wave-import.json`

## Verifikation der Welle K/B

Alle folgenden Befehle liefen mit Exit `0`:

```powershell
pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -ProjectRoot D:\_Scripte\JobAgent -FeedPath data\jobagent\company-discovery.official.wave-k-20260829.json -WaveId B
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

## Aufgaben fuer den naechsten Chat

1. `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `todo.checkpoint.json`, `handoff.latest.md` und `handoff.latest.json` lesen.
2. `git -c core.pager=cat -c color.ui=false --no-pager status --short --branch` ausfuehren und sicherstellen, dass `master...origin/master` clean ist.
3. In `data/jobagent/company-candidate-verification.queue.json` die hoechstpriorisierten Eintraege mit `next_action=DISCOVER_OFFICIAL_WEBSITE` weiter pruefen.
4. Synthetische Register-Sample-Namen wie `Alpha Technik GmbH`, `Beta Analytics AG`, `Gamma Logistics GmbH` und `Epsilon Alt GmbH` nicht produktiv aufnehmen, solange keine belastbare offizielle Website-/Karriere-Evidenz vorliegt.
5. Fuer Welle L nur Kandidaten aufnehmen, bei denen offizielle Firmenwebsite und Karriere-/Jobs-/ATS-Beleg nachvollziehbar sind. Externe ATS nur akzeptieren, wenn sie von der offiziellen Firmenwebsite belegt oder klar offiziell zugeordnet sind.
6. Neuen Feed nach Muster `data/jobagent/company-discovery.official.wave-l-20260829.json` oder mit aktuellem Datum erstellen.
7. Import ausfuehren mit `tools\Import-JobAgentCompanyDiscovery.ps1 -WaveId B`, danach Queue, Coverage, Source Coverage und die funktionsbezogenen JA-027-Tests ausfuehren.
8. `Roadmap.md`, Todo-State, Handoff und STP synchronisieren. `JA-027` erst aus `Roadmap.md` rotieren, wenn die definierte Gesamtanforderung abgeschlossen ist, nicht nur eine weitere Importwelle.

## Risiken und Regeln

- Keine erfundenen Firmen, URLs, Job-IDs, Stellen, Geodaten oder Verifikationsaussagen.
- Keine produktive Firma ohne offiziellen finalen URL-Nachweis.
- Keine Nutzung von Jobboersen-, Arbeitsagentur- oder Register-URLs als offizielle Karrierequelle.
- PowerShell-HTTP-Checks koennen bei einzelnen offiziellen Karriereseiten blockiert werden; in solchen Faellen nur mit belastbarer offizieller Linkkette weiterarbeiten, sonst fail-closed in Review lassen.
- Dedupe ueber Domains kann Tochter-/Konzernfirmen zusammenfuehren; bei notwendiger fachlicher Trennung zuerst Dedupe-Strategie anpassen und testen.
