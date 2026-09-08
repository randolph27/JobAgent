# Handoff latest

Stand: 2026-09-08T08:56:00+02:00

## Zustand

- Active: TD-0041
- Status: in-progress
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: master
- HEAD vor Commit: c2fb4c7b4c55
- Upstream: origin/master
- Ahead/Behind vor Commit: 0/0
- Worktree vor Commit: dirty
- Route: True

## Erledigter Slice

- Retry-Wiederaufnahme fuer Website-Discovery repariert.
- RETRY_SCHEDULED + DISCOVER_OFFICIAL_WEBSITE bleibt in der Queue retryfaehig und wird bei faelligem next_attempt_at wieder verarbeitet.
- Legacy-Datumswerte werden in tools/Discover-JobAgentCompanyCandidateWebsites.ps1 und tools/Verify-JobAgentCompanyCandidates.ps1 tolerant gelesen (InvariantCulture, en-US, de-DE; unparsebare Werte fail-closed als nicht datiert).
- Regression fuer faellige Retry-Scheduled-Kandidaten mit Legacy-Datum in tests/Test-JobAgentCompanyCandidateVerification.ps1 ergaenzt.
- Roadmap.md, todo.state.json, handoff.latest.* und STP-Artefakte synchronisiert.

## Aktuelle Messwerte / Evidence

- Live-Website-Discovery logs/jobagent/company-candidate-website-discovery-20260908-064627.json: processed_total=0, verified_total=0, weil vor dem naechsten Retryfenster keine faelligen Website-Discovery-Kandidaten vorhanden waren.
- Coverage logs/jobagent/company-coverage-20260908-064650.json: 487 Firmen, 439 offizielle Quellen, 2.318 Zielinventar-Kandidaten, Duplicate-Groups 0, Target-Inventory-Gap 0, Gate weiterhin failed wegen scannable/company-source-Vertragsbedingungen.
- JA-027 bleibt offen: 100er-Live-Benchmark und 1.000 belegte offizielle Karriere-/ATS-Quellen sind nicht erreicht.
- Kein Roadmap-Punkt wurde rotiert, weil JA-027 fachlich nicht komplett erledigt ist.
- Supertest wurde nicht angefragt; gemaess Nutzeranweisung gilt er fuer diesen Abschluss als erledigt/nicht nachzuholen.

## Verifikation

- pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1 -> Exit 0
- pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100 -> Exit 0, processed_total 0
- pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot . -> Exit 0, logs/jobagent/company-coverage-20260908-064650.json
- cmd /c .\ci.cmd stp -> Exit 0
- Invoke-WebRequest http://localhost:9000/api/system/status -> Exit 1, Timeout
- cmd /c .\ci.cmd sonar-start -> Exit 1, logs/terminal/error-sonar-start-latest.json, lokaler Wrapper D:\_Scripte\JobAgent\sonar.cmd fehlt

## Naechste Aufgaben fuer neuen Chat

1. Ab 2026-09-08T13:19:32+02:00 ausfuehren: pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
2. Danach Queue pruefen und fuer neue PENDING + VERIFY_OFFICIAL_SITE-Eintraege ausfuehren: pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
3. Coverage neu messen: pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
4. Wenn weiterhin ready_total=0: JA-027.2/JA-027.3 fortsetzen durch weitere erlaubte Quellen-/Snapshot-Nachfuellung oder manuell belegte Domains aus bestehenden MANUAL_REVIEW_REQUIRED-Hinweisen; keine Kandidaten-/Domain-Fakten erfinden.
5. SonarQube separat reparieren: lokalen sonar.cmd-Wrapper oder CI-Konfiguration fuer dieses Repo wiederherstellen; Serverstatus danach nur per API/Curl pruefen.

## Geaenderte Dateien

- Roadmap.md
- handoff.latest.json
- handoff.latest.md
- html/jobagent/company-coverage.html
- src/JobAgent.Coverage.psm1
- tests/Test-JobAgentCompanyCandidateVerification.ps1
- todo.checkpoint.json
- todo.events.jsonl
- todo.history.digest.json
- todo.master.index.json
- todo.state.json
- tools/Discover-JobAgentCompanyCandidateWebsites.ps1
- tools/Verify-JobAgentCompanyCandidates.ps1
