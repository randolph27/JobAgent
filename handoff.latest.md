# Handoff latest

Stand: 2026-08-26T07:15:30.225+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: `JA-025` Arbeitgeberkandidatenbasis aus erlaubten Quellen weiter skalieren; letzter Arbeitsschritt war Jobboersen-Zielgebiet und URL-Extraktion.
- Branch: `master`
- HEAD vor Commit: `8d9363415989`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
- Worktree vor Commit: `dirty`
- Route: `True`

## Arbeitsstand fuer neuen Chat

Weitergearbeitet wurde an `JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen`.

Konkretes Ergebnis:

- `src/JobAgent.JobBoardDiscovery.psm1` klassifiziert Jobboersen-Orte im Muenchner Umland jetzt als `MUNICH_20KM` statt pauschal `MUNICH`.
- Freising-/Airport-Treffer behalten Vorrang vor Muenchen-Text im Ortslabel, damit `Flughafen Muenchen / Freising` weiterhin `FREISING` bleibt.
- Der Jobboard-HTML-Parser liest `data-jobagent-url` jetzt auch an Kindknoten, z. B. an `<a data-jobagent-url="...">`.
- Dadurch wird bei `Rohde & Schwarz GmbH & Co. KG` nicht mehr `https://www.stepstone.de/Details`, sondern `https://www.stepstone.de/stellenangebote/enterprise-applications-rs-333.html` als `observed_url` und `posting_url` persistiert.
- `tests/Test-JobAgentJobBoardDiscovery.ps1` deckt `MUNICH`, `MUNICH_20KM`, Freising, Out-of-scope, Rohde-&-Schwarz-20-km-Hint und Linkknoten-URL ab.
- Snapshot-Lane wurde erneut ausgefuehrt: `sources_total=8`, `inputs_total=6`, `new_hints_total=20`, `merged_hints_total=26`, `productive_store_write=false`.
- Coverage wurde aktualisiert: `companies_total=38`, `target_inventory_candidates_total=58`, `target_inventory_gap_to_1000=942`, `target_inventory_gate_status=failed`, `candidate_verification_queue_path=data/jobagent/company-candidate-verification.queue.json`.
- Roadmap-Rotation wurde nicht ausgefuehrt, weil `JA-025` und `JA-027` weiterhin offen sind.
- Supertest wurde nicht erneut ausgefuehrt; gemaess Nutzeranweisung gilt er als erledigt, weil nicht separat angefragt und der Roadmap-Punkt noch offen ist.

## Geaenderte Dateien

- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.JobBoardDiscovery.psm1`
- `tests/Test-JobAgentJobBoardDiscovery.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Offene Roadmap

- `JA-025` bleibt offen. Es sind weiterhin mehr erlaubte Quellen/Suchmatrizen oder groessere erlaubte Snapshots erforderlich, weil die Zielgebiet-Kandidatenbasis erst `58` Kandidaten enthaelt und das Zielinventar-Gate `failed` meldet.
- `JA-027` bleibt offen und haengt fachlich weiter von `JA-025` ab. Produktive Firmenaufnahme darf erst nach offizieller Website-/Karriere-/ATS-Verifikation erfolgen.

## Naechster sinnvoller Schritt

1. In `data/jobagent/company-discovery.sources.json` die noch nicht operationalisierten oder nur manuell reviewbaren Quellen bewerten, ohne Terms/Robots zu umgehen.
2. Fuer erlaubte Quellen weitere lokale Fixtures/Snapshots oder Suchmatrizen anlegen, bevorzugt zusaetzliche BA-/StepStone-Suchkombinationen fuer Muenchen, 20-km-Umkreis und Freising sowie weitere erlaubte Register-/Regional-Snapshots.
3. Snapshot-Manifest `data/jobagent/company-discovery.snapshot.json` erweitern und danach ausfuehren: `pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane`.
4. Fokussierte Funktionstests erneut ausfuehren: Register, JobBoard, Regional, DedupeScale, Coverage.
5. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1`.
6. Erst bei fachlich kompletter `JA-025`-Erfuellung Roadmap-Rotation pruefen und danach `JA-027` fortsetzen.

## Naechster Anker

Aktive Punkte: JA-025 Arbeitgeber aus Handelsregister-, Register-, Jobboersen- und Arbeitsagentur-Quellen vollstaendig als Kandidaten erfassen #comment: Alle erlaubten Quellen sollen Arbeitgebernamen liefern, nicht Stellenanzeigen; produktiv hinzugefuegt wird erst nach offizieller Karriere-/Jobs-Webseitenverifikation.
