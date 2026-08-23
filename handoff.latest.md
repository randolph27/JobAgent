# Handoff latest

Stand: 2026-08-23T12:30:00+02:00

## Ziel fuer neuen Chat

Es gibt aktuell keinen offenen Roadmap-Punkt. Der neue Chat soll zuerst `Roadmap.md`, `Roadmap_archive.md`, `todo.current.md`, `todo.state.json` und dieses Handoff lesen. Danach entweder neue Roadmap-Punkte fachlich priorisiert anlegen oder einen neuen konkreten Nutzerauftrag ausfuehren.

## Aktueller Zustand

- Active: none
- Todo: keine offenen Items
- Roadmap: keine aktiven Punkte
- Branch: master
- HEAD: 681eff81576a
- Upstream: origin/master
- Ahead/Behind vor Push: 1/0
- Worktree vor abschliessendem STP-Commit: dirty durch STP-/Handoff-Dateien
- Devserver: http://localhost:8500 antwortete zuletzt mit HTTP 200
- SonarQube: http://localhost:9000/api/system/status meldete zuletzt `UP`, Version 26.1.0.118079

## Abgeschlossen

JA-030 ist abgeschlossen und nach `Roadmap_archive.md` rotiert. `Roadmap.md` enthaelt nur noch den Abschnitt "Keine aktiven Punkte.".

Umgesetzt in JA-030:

- Freshness-Modell fuer Firmen, Discovery-Quellen und Kandidaten mit `last_imported_at`, `last_verified_at`, `expires_at`, `next_refresh_at`, `refresh_reason` und `staleness_status`.
- Coverage-Metriken fuer `company_fresh`, `company_refresh_due`, `candidate_refresh_due`, Quellen-Freshness, Kandidaten-Freshness und Refresh-Gruende.
- Coverage-Markdown und Coverage-HTML um Freshness-Status, Refresh-Gruende, Kandidaten-Freshness und Firmeninventar-Spalten fuer Freshness erweitert.
- Daily-Run-Priorisierung erweitert: refresh-faellige Firmen werden vor regulaeren Scanfaellen beruecksichtigt; erfolgreiche und fehlgeschlagene Scans persistieren Freshness-Felder.
- Betriebsdokumentation `docs/company-discovery-operations.md` erstellt.
- Todo-/Roadmap-Zustand synchronisiert und STP ausgefuehrt.

## Wichtige Dateien

- `src/JobAgent.Coverage.psm1`: Freshness-Berechnung, Source-/Candidate-Freshness-Reports, Coverage-Metriken.
- `src/JobAgent.DailyRun.psm1`: Refresh-faellige Firmen in Sortierung und Persistenz von Freshness-Feldern.
- `tools/Measure-JobAgentCompanyCoverage.ps1`: Markdown-/HTML-Ausgabe fuer Freshness und Kandidaten-Freshness.
- `tests/Test-JobAgentCoverage.ps1`: Assertions fuer Freshness-Metriken und Report-Ausgabe.
- `tests/Test-JobAgentDailyRun.ps1`: Assertions fuer Daily-Run-Priorisierung und Persistenz.
- `docs/company-discovery-operations.md`: Betriebs- und Freshness-Vertrag.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1` -> Exit 0
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd self-check` -> Exit 0
- `.\ci.cmd stp` -> Exit 0

Hinweis: Ein historischer Verify-Digest verweist weiterhin auf `.\gradlew.bat verify --console=plain --no-daemon` mit Status `running`; im Projekt liegt kein Gradle-Wrapper. Fuer diesen Stand sind die oben genannten PowerShell-Funktionstests und der Supertest massgeblich.

## Naechste Aufgaben

1. Bei neuem Nutzerauftrag direkt ausfuehren.
2. Wenn neue Roadmap-Arbeit gewuenscht ist, neue Punkte nicht in Eingabereihenfolge, sondern nach Abhaengigkeiten, kritischem Pfad, Wert pro Aufwand, Risiko und Unsicherheit priorisieren.
3. Keine Massenaufnahme unverifizierter Kandidaten, keine Vollstaendigkeitsbehauptung fuer alle Firmen und keine extern wirksame Aktion ohne ausdrueckliche Bestaetigung.

CAPSULE:{"ts":"2026-08-23T12:30:00+02:00","agent_id":"codex","workspace_root":"D:\\_Scripte\\JobAgent","project":"JobAgent","active_id":null,"status":"done","goal":"JA-030 abgeschlossen; keine aktive Roadmap-Aufgabe vorhanden.","changed":["handoff.latest.json","handoff.latest.md","todo.events.jsonl","todo.history.digest.json","todo.master.index.json"],"verified":[{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentDailyRun.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentOperations.ps1","exit":0,"status":"pass"},{"cmd":".\\ci.cmd supertest","exit":0,"status":"pass"},{"cmd":".\\ci.cmd self-check","exit":0,"status":"pass"},{"cmd":".\\ci.cmd stp","exit":0,"status":"pass"}],"route_ok":null,"route_violations":[],"git":{"has_repo":true,"branch":"master","detached":false,"head":"681eff81576a","upstream":"origin/master","remote":"origin","ahead":1,"behind":0,"worktree":"dirty","tracked_changes":["handoff.latest.json","handoff.latest.md","todo.events.jsonl","todo.history.digest.json","todo.master.index.json"]},"next":"Neuen Nutzerauftrag abwarten oder neue Roadmap-Punkte priorisiert anlegen.","refs":["todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.json","Roadmap.md","Roadmap_archive.md"],"manual_missing":false,"env_inventory_missing":false,"env_inventory_used":false,"env_inventory_path":null}
