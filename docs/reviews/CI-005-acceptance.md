# CI-005 – Immutable- und Handoff-Invarianten

Stand: 2026-09-16

## Herkunftsentscheidung

`manual/PROGRAM.md` hat SHA-256 `62E616E167CB6F6F707726F84D96B1987066B170BE38A2EE4486927DC0F9EDF3` und keinen Git-Diff gegen `HEAD`. Der aktuelle Inhalt ist durch die Commits `12216591f3bd18e8ec8125dde5d6a9642bd0c97b` (berufsneutrale Erfassung) und `ca3f8bbe77eb02b9672c707a74102cfa822c4639` (getrennte Stellengültigkeit und Profilpassung) belegt.

Der vorherige Immutable-Snapshot enthielt den überholten IT-Führungsprofilvertrag mit SHA-256 `F2F017A1BF9752A8F6203831E093DC9914C89AE0C3D577010591F21D4F79ACDD`. Er wurde gezielt auf den bereits versionierten Programmvertrag synchronisiert. Ausschließlich der Hash für `manual/PROGRAM.md` und dessen Snapshot wurden aktualisiert; keine produktive Programmdokumentation wurde überschrieben und kein vollständiges Re-Pinning ausgeführt.

## Handoff- und Driftzustand

`handoff.latest.md` wird erneut deterministisch aus `handoff.latest.json` gerendert. Der synchronisierte Handoff enthält Branch `master`, HEAD `aee7a9553e81` und Worktree `dirty`; die Werte sind mit dem JSON-Snapshot identisch.

Der Observer-Baseline-Snapshot wurde nach der belegten Pin-Synchronisierung erneuert. `logs/observer/drift-latest.json` weist `immutables_ok: true`, `route_ok: true`, `changed_sources: 0` und `drift: false` aus.

## Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` – Exit 0. Der neue isolierte CI-005-Test prüft die vier Negativklassen `immutable_modified`, fehlenden Handoff-Branch, fehlenden Handoff-HEAD und fehlenden Handoff-Worktree.
- `.\ci.cmd self-check` – Exit 0; Evidence: `logs/terminal/self-check-20260916-172435.log`.
- `.\ci.cmd route-check` – Exit 0; Evidence: `logs/terminal/route-check-20260916-172439.log`.
- `.\ci.cmd observer-baseline` – Exit 0.
- `.\ci.cmd drift-check` – Exit 0; Evidence: `logs/observer/drift-latest.json` und `logs/terminal/route-check-20260916-172451.log`.

Supertest wurde nicht ausgeführt und gemäß Nutzerregel als erledigt bewertet; CI-005 betrifft ausschließlich CI-Integrität und die fokussierten Funktionstests sind grün.
