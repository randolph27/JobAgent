# Handoff latest

Stand: 2026-09-17T11:19:12.036+02:00 (nach dem STP um den externen Security-Blocker ergänzt)

## Zustand

- Active: `TD-0066 / QA-007`
- Status: `blocked`
- Ziel: Den Vollsupertest erst nach Freigabe bzw. Klärung des Kaspersky-Befunds erneut ausführen.
- Branch: `master`
- HEAD: `22bc9c9c31e6`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `./ci.cmd supertest` -> Exit 1; erster von 29 Fällen (`QA-006-CI-CONTRACT`) erhielt Exit 5, 28 Fälle wurden nicht ausgeführt.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit 0 nach Wiederherstellung der fehlenden, unverändert aus HEAD stammenden Testdatei.
- `pwsh -NoProfile -File .\tests\Test-JobAgentSupertestContract.ps1` -> Exit 0; sechs Runner-Vertragsfälle grün.
- `pwsh -NoProfile -File .\tests\Test-JobAgentSupertest.ps1` -> nicht abgeschlossen: Kaspersky System Watcher meldete bei `tests\test-jobagentcicontracts.ps1` `PDM:Trojan.Win32.Generic`; der gestartete fokussierte Lauf wurde kontrolliert beendet.
- `.\ci.cmd sonar` -> `not-supported` (keine Codeanalyse behauptet).

## Blocker

Kaspersky hat die Ausführung des CI-Vertragstests als `PDM:Trojan.Win32.Generic` gemeldet. Ohne eine nachvollziehbare Security-Entscheidung darf weder eine Ausnahme angelegt noch „Disinfect and restart“ ausgelöst werden. Die Testdatei ist eine unveränderte Wiederherstellung aus `HEAD`; ein tatsächlicher Befund oder ein False Positive ist nicht bestimmt. Der nächste Agent muss zuerst das lokale Kaspersky-Ereignis und den Quarantäne-/Dateistatus prüfen, den Nutzerentscheid dazu einholen und erst anschließend QA-007s fokussierten Runner-Test sowie den Vollsupertest wiederholen.

## Naechster Anker

QA-007 ist offen und durch den dokumentierten Kaspersky-Befund blockiert. Nach gesicherter Security-Freigabe: Screenshot als `doc/roadmap-screenshots/QA-007-*.png` ablegen, Testdatei gegen `HEAD` hashen, den fokussierten Runner-Test zu Ende führen und anschließend `./ci.cmd supertest` mit 29/29 Fällen ausführen.
