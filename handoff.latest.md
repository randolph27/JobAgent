# Handoff latest

Stand: 2026-08-23T12:02:30+02:00

## Ziel fuer neuen Chat

Direkt mit TD-0030 / JA-030 weitermachen: laufenden Coverage-Betrieb, Drift-Erkennung und Quellen-Freshness fuer Muenchen/Freising etablieren.

## Aktueller Zustand

- Active: TD-0030
- Status: open
- Branch: master
- HEAD vor diesem STP-/Handoff-Commit: d9ba8f9d700
- Upstream: origin/master
- Ahead/Behind vor Push: 1/0
- Worktree zum STP-Zeitpunkt: dirty
- Letzter Feature-Commit: d9ba8f Complete JA-029 import wave gates
- STP: .\ci.cmd stp lief am 2026-08-23T12:01:52+02:00 erfolgreich mit Exit 0.
- Devserver: http://localhost:8500 antwortete mit HTTP 200.
- SonarQube: http://localhost:9000/api/system/status meldete UP, Version 26.1.0.118079.

## Abgeschlossen

JA-029 ist abgeschlossen und nach Roadmap_archive.md rotiert. Roadmap.md enthaelt nur noch JA-030 als aktiven Punkt.

Umgesetzt fuer JA-029:

- Importwellen-Konfiguration A-D mit Zielgroessen, Pflicht-Evidence, erlaubten Verifikationsstatus, Dubletten-/Review-Grenzen und Rollback-Pflicht.
- Fail-closed Gate fuer produktive Wellenimporte: Schema, Store-Dokument, Coverage-Delta, Dublettenrate, Manual-Review-Rate, erlaubte Status, Pflicht-Evidence und Backup werden geprueft.
- Gate-Verletzungen schreiben Failure-Evidence-Logs und verhindern Store-Writes.
- Coverage-Report enthaelt Wellenmetriken: Kandidaten, Firmen, verifiziert, nur Hinweis, Review, scanfaehig, Annahmequote, Dublettenquote, Verifikationsquote, Scanfaehigkeitsquote, Coverage-Delta, Gate-Status, Backup-Pfad.
- Coverage-HTML fuer grosse Listen erweitert: Scroll-Container, Sticky-Header, segmentiertes Firmeninventar, keine externen Ressourcen.
- Erneuter Welle-A-Import vorhandener offizieller Feed-Firmen bricht korrekt fail-closed ab (DUPLICATE_RATE_EXCEEDED, MIN_ADDED_COMPANIES_NOT_REACHED); Store blieb unveraendert.

## Verifikation

- pwsh -NoProfile -File tests\Test-JobAgentImportWaves.ps1 -> Exit 0
- pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1 -> Exit 0
- pwsh -NoProfile -File tests\Test-JobAgentReport.ps1 -> Exit 0
- pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1 -> Exit 0
- pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1 -> Exit 0
- .\ci.cmd supertest -> Exit 0
- .\ci.cmd self-check -> Exit 0
- .\ci.cmd stp -> Exit 0

Nicht als aktueller Nachweis werten:

- .\gradlew.bat verify --console=plain --no-daemon: im Projekt liegt kein gradlew/gradlew.bat; alter Verify-Digest zeigt unning und ist historisch.

## Naechste Aufgabe

JA-030 umsetzen:

1. Freshness-Modell implementieren: pro Quelle/Kandidat last_imported_at, last_verified_at, xpires_at, 
ext_refresh_at, efresh_reason, staleness_status berechnen und persistieren.
2. Drift- und Betriebsreports erweitern: Coverage nach Gebiet, Quelle, Verifikationsstatus, Alter, Review-Queue, Fehlerklasse und naechster Aktion ausgeben; grosse HTML-Listen filterbar oder segmentiert halten.
3. Daily-Run-Priorisierung anpassen: Firmen-Jobscan, Kandidatenverifikation und Quellenrefresh getrennt budgetieren.
4. docs/company-discovery-operations.md erstellen/erweitern.
5. Funktionstests fokussiert ausfuehren: 	ests\Test-JobAgentCoverage.ps1, 	ests\Test-JobAgentDailyRun.ps1, 	ests\Test-JobAgentOperations.ps1; Supertest erst nach Abschluss von JA-030.

## Harte Grenzen

- Keine Massenaufnahme unverifizierter Kandidaten.
- Keine stille Loeschung abgelaufener Kandidaten oder Firmen.
- Keine Vollstaendigkeitsbehauptung fuer alle Muenchner/Freisinger Firmen ohne definierte Quellenabdeckung.
- Jobboersen bleiben Discovery-Hinweise, keine Primaerbelege.
- Keine Bewerbung, kein Kontaktformular, kein externer Schreibzugriff ohne ausdrueckliche Bestaetigung.
- Keine Secrets in Logs, Reports, Todo, Handoff oder Git.

CAPSULE:{"ts":"2026-08-23T12:02:30+02:00","agent_id":"codex","workspace_root":"D:\\_Scripte\\JobAgent","project":"JobAgent","active_id":"TD-0030","status":"open","goal":"JA-030 Laufender Coverage-Betrieb, Drift-Erkennung und Quellen-Freshness fuer Muenchen/Freising etablieren.","changed":["handoff.latest.json","handoff.latest.md","todo.events.jsonl","todo.history.digest.json","todo.master.index.json"],"verified":[{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentImportWaves.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentReport.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentTestMatrix.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentHtmlAudit.ps1","exit":0,"status":"pass"},{"cmd":".\\ci.cmd supertest","exit":0,"status":"pass"},{"cmd":".\\ci.cmd self-check","exit":0,"status":"pass"},{"cmd":".\\ci.cmd stp","exit":0,"status":"pass"}],"route_ok":null,"route_violations":[],"git":{"has_repo":true,"branch":"master","detached":false,"head":"bd9ba8f9d700","upstream":"origin/master","remote":"origin","ahead":1,"behind":0,"worktree":"dirty","tracked_changes":["handoff.latest.json","handoff.latest.md","todo.events.jsonl","todo.history.digest.json","todo.master.index.json"]},"next":"Mit TD-0030 / JA-030 starten: Freshness-Modell, Drift-/Betriebsreports und Daily-Run-Priorisierung implementieren.","refs":["todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.json","Roadmap.md","Roadmap_archive.md"],"manual_missing":false,"env_inventory_missing":false,"env_inventory_used":false,"env_inventory_path":null}
