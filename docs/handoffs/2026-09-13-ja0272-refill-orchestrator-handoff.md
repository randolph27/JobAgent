# JA-027.2 Refill-Orchestrator Handoff

Stand: 2026-09-13T19:45:00+02:00

## Ergebnis

- `tools/Invoke-JobAgentDiscoveryRefill.ps1` angelegt.
- Der Refill importiert nur erlaubte Snapshotquellen aus `data/jobagent/company-discovery.snapshot.json`, ueberspringt `REJECT`/blockierte Quellen, persistiert pro Manifesteintrag den Inputhash in `data/jobagent/company-discovery.refill.state.json` und importiert unveraenderte Snapshots nicht erneut.
- Nach jedem Refill wird `data/jobagent/company-candidate-verification.queue.json` aus Hint-Store, Registry, Store und vorheriger Queue neu aufgebaut.
- `tools/Invoke-JobAgentDailyRun.ps1` startet den Refill vor Website-Ermittlung und Kandidatenverifikation innerhalb der automatischen Akquisephase.
- Fehlende Registry/Manifest-Dateien blockieren Fixture-/Minimal-Daily-Runs nicht, sondern ergeben `source_refill.status=SKIPPED`.

## Verifikation

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
```

Beide Funktionstests liefen gruen. Kein Supertest, weil JA-027 insgesamt noch offen ist.

## Naechster Anker

JA-027.3: Domain-only-Firmen und bereits `VERIFIED`/`ALREADY_VERIFIED_IN_STORE` markierte Kandidaten wieder in einen getrennten Karrierequellen-Pruefauftrag bringen; logische Hostwellen vor HTTP speichern und neue eindeutige Karrierearbeitgeber getrennt von Domain-only-Erfolgen messen.
