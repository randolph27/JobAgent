# Handoff latest

Stand: 2026-09-13T19:42:05+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand liefern.
- Erledigter Slice: JA-027.2 Quellen mit verwertbaren Website-/Karrierehinweisen priorisieren und die ausfuehrbare Queue automatisch nachfuellen.
- Branch: `master`
- HEAD vor Commit: `f300584bcd19`
- Upstream: `origin/master`
- Worktree: wird fuer Commit bereinigt.
- Route: `True`

## Ergebnis

- `tools/Invoke-JobAgentDiscoveryRefill.ps1` fuehrt einen endlichen Snapshot-Refill aus, wenn keine startbare Queue vorliegt.
- Erlaubte Snapshotquellen werden ueber Registry/Manifest validiert; `BLOCKED`/`REJECT`/nicht freigegebene Quellen bleiben ausgeschlossen.
- Pro Quelle wird ein Inputhash-Cursor in `data/jobagent/company-discovery.refill.state.json` persistiert; unveraenderte Quellen werden nicht erneut importiert.
- Regional-, Register- und Jobboard-Importe werden angebunden; danach wird `company-candidate-verification.queue.json` neu aufgebaut.
- `Invoke-JobAgentDailyRun.ps1` ruft den Refill in der Akquisephase vor Website-Ermittlung und Kandidatenverify auf und dokumentiert `acquisition.source_refill` mit Status, Grund, Importanzahl, Logpfad und `wake_at`.
- Roadmap, Todo, Handoff und STP-Sync wurden aktualisiert. Es wurde kein kompletter Roadmap-Hauptpunkt herausrotiert, weil `JA-027` weiterhin offen ist.

## Versionierte Aenderungen

- `Roadmap.md`
- `tools/Invoke-JobAgentDiscoveryRefill.ps1`
- `tools/Invoke-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentDiscoverySourceInventory.ps1`
- `docs/handoffs/2026-09-13-ja0272-refill-orchestrator-handoff.md`
- `todo.current.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.checkpoint.json`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`
- `cmd /c .\ci.cmd route-check` -> Exit `0`

## Naechster Anker

JA-027.3: Domain-only-/bereits-verifizierte Kandidaten in getrennte Karrierequellen-Pruefung bringen, Hostwellen logisch planen und neue Karrierearbeitgeber getrennt von Domain-only messen.

## Hinweise fuer den neuen Chat

- Nicht zu `JA-041` springen; aktueller aktiver Punkt bleibt `TD-0041`/`JA-027`.
- Naechster zusammenhaengender Slice: `JA-027.3`. Ziel ist, Domain-only- und bereits websiteverifizierte Kandidaten nicht mit neuer Firmenakquise zu vermischen, sondern in eine getrennte Karrierequellen-Pruefung/Hostwelle zu bringen.
- Metrik weiter an neuen belegten Karriere-/ATS-Arbeitgebern ausrichten, nicht an globalen Resets oder Importmengen.
- Supertest ist nicht ausstehend, weil er nicht angefragt wurde.
