# Handoff latest

Stand: 2026-09-06T17:35:41.922+02:00. STP wurde ausgefuehrt. Fuer neuen Chat/Agent: zuerst `README.md`, `Roadmap.md`, `todo.current.md`, `todo.state.json`, `handoff.latest.md` lesen. Projektwurzel ist `D:\_Scripte\JobAgent`.

## Aktiver Status

- Active: `TD-0041` / `JA-027`
- Status: `in-progress`
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen.
- Branch: `master`
- HEAD beim STP: `803e9548bb60`
- Upstream: `origin/master`
- Ahead/Behind beim STP: `0/0`
- Worktree beim STP: `dirty`
- Roadmap-Rotation: nicht ausgefuehrt, weil kein Top-Level-Punkt komplett erledigt ist.

## Erledigter Stand

JA-027.1 ist als Retention-Schnitt umgesetzt und gepusht.

Technischer Stand:
- `src/JobAgent.Persistence.psm1`: `jobagent/v1` enthaelt und normalisiert `discovery_inventory` und `discovered_urls`.
- `src/JobAgent.CompanyInventory.psm1`: Seed-/Discovery-Importe schreiben dauerhafte Firmen- und URL-Funde idempotent; Name-only-Hints werden als dauerhafte Kandidaten mit `company_id=null` und `promoted_to_company=false` gespeichert.
- `tools/Import-JobAgentCompanyDiscovery.ps1`: Snapshot-Refresh loescht nicht erneut beobachtete Hints nicht mehr, sondern markiert sie als `retention_status=NOT_OBSERVED_IN_SOURCE`; zusaetzlich wird Retention in den Store geschrieben, ohne produktive `companies` oder `job_sources` zu erzeugen.
- Dokumentation aktualisiert: `docs/data-model.md`, `docs/company-discovery-operations.md`, `docs/company-discovery-source-contract.md`.

Produktivdaten:
- `data/jobagent/store.json` migriert.
- Firmen: 479 vorher/nachher.
- JobSources: 439 vorher/nachher.
- Discovery-Funde: 2.269.
- URL-Funde: 1.401.
- Unbegruendeter Firmenverlust: 0.
- Backups: `data/jobagent/backups/store-20260906T110833936Z-ja027-retention-migration.json`, `data/jobagent/backups/store-20260906T152824952Z-ja027-hint-retention-migration.json`.

Evidence:
- `logs/jobagent/JA-027-retention-migration.json`
- `logs/jobagent/JA-027-retention-regression.json`

Commits:
- `304b38e349dd` Implement JA-027 retention inventory
- `803e9548bb60` Sync JA-027 retention handoff

## Verifikation

Ausgefuehrt und gruen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentPersistence.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentImportWaves.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1
cmd /c .\ci.cmd self-check
git -c core.pager=cat -c color.ui=false --no-pager diff --check
cmd /c .\ci.cmd stp
```

Supertest wurde nicht ausgefuehrt. Nach aktueller Nutzeranweisung gilt er fuer diesen Handoff als erledigt/freigestellt, aber nicht als bestandener Testlauf. Grund: JA-027 ist noch nicht komplett abgeschlossen.

## Offene Arbeit fuer den naechsten Chat

Naechster Hotspot ist JA-027.2: Quellenerschliessung/Source-Inventur. Nicht zu JA-041 springen, obwohl STP gelegentlich den naechsten Top-Level-Punkt nennt; `TD-0041` bleibt aktiv.

Konkrete naechste Schritte:
1. `data/jobagent/company-discovery.sources.json`, `data/jobagent/company-discovery.snapshot.json`, `data/jobagent/company-discovery.hints.json`, Queue und Store gegeneinander inventarisieren.
2. Alle 32 Registry-Quellen auswerten: Betreiber, URL, Klasse, Format, Snapshotdatum/-hash, Suchparameter, Recordzahl, eindeutige Retention-Funde, bekannte Firmen, URL-Hinweise, offene Gruende, Importmodus und naechste Aktion.
3. Die fuenf Hints ohne Queueeintrag einzeln erklaeren.
4. Kleine BA-/StepStone-/Indeed-/Register-Bestaende auf Testherkunft oder echte geringe Ausbeute pruefen; nicht als Quellenerschoepfung behaupten.
5. Mindestens sechs neue Quellenansaetze recherchieren und dokumentieren: Kammer-/Branchenverzeichnisse Muenchen/Oberbayern, kommunale Gewerbeverzeichnisse im Muenchen-20-km-Bereich, Freising Stadt/Landkreis, Forschungs-/Hochschul-Ausgruendungen, Technologiepark-/Cluster-Mitglieder, lizenzierte Organisations-Open-Data.
6. Evidence fuer JA-027.2 erzeugen: `logs/jobagent/JA-027-source-inventory.json`, `logs/jobagent/JA-027-source-research.json`, `logs/jobagent/JA-027-candidate-reconciliation.json`.

Danach JA-027.3:
- offizielle Firmen-/Karriereverifikation,
- 100er Live-Benchmark mit echten unterscheidbaren Kandidaten,
- Scheduler/Resume ueber Hostwellen,
- P50/P95, Requests/Nenner, Nettozuwachs,
- Ziel: 1.000 belegte offizielle Karriere-/ATS-Arbeitgeberquellen.

## Grenzen

- Keine erfundenen Firmen, URLs, Stellen oder Vollstaendigkeitsnachweise.
- Jobboersen/Register/OSM/Communitylisten liefern nur Hinweise, keine offiziellen Karrierequellen.
- Unverifizierte Hints bleiben Retention-Kandidaten, keine produktiven Companies/JobSources.
- Keine Bewerbungen, Nachrichten, Login-/Captcha-/Paywall-Umgehung oder kostenpflichtigen Zugaenge.
- Devserver/Sonar nur ueber `.\ci.cmd`, Server im Hintergrund.
