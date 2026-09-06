# Handoff latest

Stand: 2026-09-06T22:56:27.464+02:00. STP wurde ausgefuehrt. Projektwurzel ist `D:\_Scripte\JobAgent`.

## Aktiver Status

- Active: `TD-0041` / `JA-027`
- Status: `in-progress`
- Branch: `master`
- HEAD: `07bc582b653f`
- Worktree: `dirty`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich offen bleibt.
- Supertest: nicht ausgefuehrt, da JA-027 noch nicht abgeschlossen ist.

## Abgeschlossener Arbeitsschritt

JA-027.2 hat jetzt testgedeckte Quellenentscheidungen fuer die vier offenen Rechercheansaetze in `logs/jobagent/JA-027-source-research.json`:

- HWK Muenchen/Oberbayern Handwerkersuche: `blocked_for_automated_import`, kein Formular-/Massensuchimport ohne separate Ergebnis-Snapshotfreigabe.
- BioM Company Database / Interactive Cluster Map / Reports: `deferred_for_parser_contract`, geparkt bis zu einem abgegrenzten Report-/Database-Snapshotvertrag ohne Kontakt-/Personenfelder.
- Stadt Freising Wirtschaft: `no_new_source_registered`, allgemeine Wirtschaftsseite bleibt Recherchekontext; konkrete Organisationslisten nur ueber eigene Source-ID, bestehend `source-registry:stadt_freising_weihenstephan`.
- IHK Standortportal Bayern: `not_registered_for_import`, kein Import ohne dokumentierte Unternehmensstandort-Export-/API- und Retentionfreigabe.

Damit wird keine neue offizielle Karrierequelle behauptet und keine produktive Firma erzeugt. Bestehende Zahlen bleiben: 35 Registry-Quellen, 29 Snapshot-Manifesteintraege, 1.833 Hints, 1.831 Queue-Cluster, 2.312 Retention-Funde und 1.401 URL-Funde.

## Geaenderte Hauptdateien

- `tools/Measure-JobAgentDiscoverySourceInventory.ps1`
- `tests/Test-JobAgentDiscoverySourceInventory.ps1`
- `Roadmap.md`
- `todo.state.json`
- STP-Artefakte: `handoff.latest.json`, `handoff.latest.md`, `todo.checkpoint.json`, `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`

## Evidence

- `logs/jobagent/JA-027-source-research.json`
- `logs/jobagent/JA-027-source-inventory.json`
- `logs/jobagent/JA-027-candidate-reconciliation.json`

## Verifikation

Gruen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1
cmd /c .\ci.cmd self-check
git -c core.pager=cat -c color.ui=false --no-pager diff --check
cmd /c .\ci.cmd stp
```

Hinweis: Ein erster `cmd /c .\ci.cmd self-check` vor STP schlug erwartbar mit `todo_checkpoint_invariant` fehl, weil `todo.state.json` bereits aktualisiert und `todo.checkpoint.json` noch nicht synchronisiert war. Nach `stp` ist self-check gruen.

## Naechste Aufgabe

Naechster Hotspot bleibt innerhalb `JA-027`: `JA-027.3` starten. Offizielle Firmen-/Karriereverifikation und 100er Benchmark vorbereiten; dabei die Quellenentscheidungen aus `JA-027-source-research.json` respektieren und keine geparkte/blockierte Quelle fuer Import oder Mengenbehauptungen nutzen.