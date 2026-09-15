# Handoff latest

Stand: 2026-09-15T19:54:23.202+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel:
- Branch: `master`
- HEAD: `75cfdb85693f`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `tests/Test-JobAgentReport.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

QA-003 Discovery, Quellenverifikation, Wiederanlauf und CLI-Betrieb vollstaendig testen #comment: Der regulaere Start muss vom Firmenhinweis bis zur atomaren WebIF-Publikation einschliesslich Transportfehlern deterministisch nachgewiesen sein.

## Fachlicher Uebergabestatus

- QA-001 und QA-002 sind in `Roadmap_archive.md` archiviert. `TD-0059` wurde als abgeschlossen aus dem aktiven Todo entfernt; `todo.current.md` enthaelt nun QA-003 bis QA-006 und TD-0056.
- QA-002.3 ist in `Test-JobAgentReport.ps1` umgesetzt: Eine isolierte persistierte Storegeneration wird erneut geladen und in Daily-Report-JSON, Markdown, Daily-HTML und Coverage-JSON umgewandelt. Assertions pruefen feste Job-/Firmen-IDs, Mengen, Capture-Manifest, Teilgrenze, A/B-Prioritaeten, UNKNOWN, lange Unicodewerte, HTML-/Script-Escaping, die Sperre von `javascript:`-Links sowie Gleichheit zweier Laeufe mit festem Zeitpunkt.
- Alle acht QA-002-Funktionstests endeten mit Exit 0. `Test-JobAgentSchema.ps1` benoetigte Zugriff auf den vorhandenen lokalen npm-Cache ausserhalb der Sandbox; der Rest lief lokal isoliert. Kein Produktionsmodul wurde geaendert.
- Der Supertest wurde nicht ausgefuehrt. Nach Nutzerregel ist er als erledigt behandelt, ohne einen gruennen Lauf zu behaupten.

## Naechster Arbeitsschnitt: QA-003.1

1. Bestehende Register-, Jobboersen- und Regionalfixtures gegen leere, duplizierte, veraltete, ungueltige und UNKNOWN-Faelle erweitern.
2. Offizielle Verifikation fail-closed pruefen: nur offizielle Website-, Karriere- oder ATS-Belege duerfen importierte Firmen bestaetigen; Aggregatoren, fremde Redirects, Login/Captcha und unbelegte URLs bleiben Hinweise.
3. Die vorhandenen Tests `Test-JobAgentCompanyCandidateVerification.ps1`, `Test-JobAgentRegisterDiscovery.ps1`, `Test-JobAgentJobBoardDiscovery.ps1`, `Test-JobAgentRegionalDiscovery.ps1`, `Test-JobAgentCompanyDedupeScale.ps1` und `Test-JobAgentDiscoverySourceInventory.ps1` gezielt erweitern und einzeln ausfuehren. Keine Live-Webrecherche, produktiven Stores oder fremden Prozesse veraendern.

Danach folgen QA-003.2 (Adapter-/Transportfehler mittels Fixtures), QA-003.3 (isolierte CLI-/Resume-Laeufe), QA-004 (UI-Zustandsmatrix), QA-005 (Layout und Tastatur) und QA-006 (matrixgesteuerter Aggregator). TD-0056 bleibt eine reine Driftanalyse ohne Pin-, Snapshot- oder Immutable-Kosmetik.
