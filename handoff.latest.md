# Handoff latest

Stand: 2026-08-23T11:45:00+02:00

## Ziel fuer neuen Chat

Direkt mit `TD-0029` / `JA-029` weitermachen: produktive Erweiterungswellen fuer tausende Muenchen-/Freising-Arbeitgeber mit Coverage-Gates einfuehren.

Nicht mit JA-030 starten. `JA-030` ist weiterhin offen, aber fachlich nachgelagert zu JA-029.

## Aktueller Zustand

- Active: `TD-0029`
- Status: `in-progress`
- Branch: `master`
- HEAD vor Abschluss-Commit: `0a871afb9079`
- Worktree vor Abschluss-Commit: `dirty`
- Roadmap aktiv: `JA-029`, `JA-030`
- Roadmap rotiert: `JA-028` wurde nach `Roadmap_archive.md` verschoben und in `Roadmap_index.md` als archiviert bis `JA-028` erfasst.
- Todo rotiert: `TD-0028` ist `done`, `TD-0029` ist `in-progress`, `TD-0030` ist `open`.
- STP: `.\ci.cmd stp` lief erfolgreich mit Exit 0 am 2026-08-23T11:38:06+02:00.
- Supertest: nicht erneut ausgefuehrt; laut Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt.

## Abgeschlossener Punkt

`JA-028 Offizielle Firmenwebsite-, Karriere- und ATS-Verifikation fuer Kandidaten automatisieren` ist fachlich abgeschlossen.

Umgesetzt:

- Candidate-Verification-Queue unter `data/jobagent/company-candidate-verification.queue.json`.
- Queue-Eintraege mit Cluster-ID, Kandidaten-IDs, Canonical Name, Source Count, Priority Score, Zielgebietsbasis, Status, Review-Grund, Retry Count, letzter Versuch, naechster Versuch, letztem Status und letztem Grund.
- Verifikationslauf in `tools/Verify-JobAgentCompanyCandidates.ps1` verarbeitet nur faellige Kandidaten, respektiert MaxCandidates/Timeout/MaxRetries und persistiert `VERIFIED`, `MANUAL_REVIEW_REQUIRED`, `RETRY_SCHEDULED`, `RETRY_EXHAUSTED`.
- Produktiver Upsert bleibt fail-closed: Firmen werden nur bei `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED` oder `OFFICIAL_ATS_VERIFIED` aktualisiert; JobSources entstehen nur bei `CAREER_URL_VERIFIED` oder `OFFICIAL_ATS_VERIFIED`.
- `src/JobAgent.SourceVerification.psm1` erzwingt `KNOWN_COMPANY_DOMAIN_MISMATCH` in Manual Review.
- `src/JobAgent.Coverage.psm1` erzeugt Queue-Metriken und `candidate_verification_decision_report`.
- `tools/Measure-JobAgentCompanyCoverage.ps1` gibt den Review-/Reject-Report in JSON, Markdown und HTML aus.
- `html/jobagent/company-coverage.html` wurde aktualisiert und enthaelt die Abschnitte `Kandidaten-Verifikationsqueue` und `Review-/Reject-Report`.
- Immutable Pins wurden mit `.\ci.cmd repin-immutables` aktualisiert.

## Verifikation

Gruen:

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0
- `.\ci.cmd repin-immutables` -> Exit 0
- `.\ci.cmd stp` -> Exit 0

Nicht ausgefuehrt:

- `.\ci.cmd supertest`; nicht angefragt und laut Nutzeranweisung als erledigt zu werten.

## Geaenderte Dateien

- `.ci/pins/immutable.hashes.json`
- `.ci/pins/immutable.snapshot/Roadmap.md`
- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.Coverage.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `tests/Test-JobAgentCoverage.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`
- `tools/Measure-JobAgentCompanyCoverage.ps1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`

## Naechste Aufgabe

Mit `JA-029` beginnen:

1. Wellenkonfiguration erstellen: Zielgroessen, Quellmix, Mindest-Evidence, maximale Dublettenquote, maximale Review-Quote und Rollback-Backup pro Welle definieren.
2. Import-Gate implementieren: Vor jedem produktiven Upsert Schema, Dedupe, Evidence, Rate-Limit, Coverage-Delta und Backup pruefen; bei Gate-Verletzung keine Teiluebernahme.
3. Store und Report skalieren: Sortierung, Pagination/HTML-Tabellen, Coverage-Ausgabe und Daily-Run-Kandidatenpriorisierung fuer tausende Firmen stabilisieren.

Pflicht fuer JA-029:

- Keine Massenaufnahme unverifizierter Kandidaten.
- Kein Loeschen bestehender Firmen ohne expliziten Auftrag.
- Keine riesigen Rohdaten-Dumps committen.
- Keine Vollstaendigkeitsbehauptung "alle Firmen" ohne definierte Quellenabdeckung.
- Funktionstests zuerst: `tests\Test-JobAgentImportWaves.ps1`, `tests\Test-JobAgentCoverage.ps1`.
- Supertest erst nach gruenen Funktionstests und nur, wenn der Roadmap-Punkt abgeschlossen wird oder explizit angefragt ist.
