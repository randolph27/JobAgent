# Handoff: JA-027.2 URL-Hint-Transport

Stand: 2026-09-13T19:18:44+02:00

Active: `TD-0041` / `JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand liefern`.

## Ergebnis dieses Slices

Der JA-027.2-Hotspot wurde um den durchgaengigen Transport vorhandener Website-/Karrierehinweise erweitert:

- `src/JobAgent.RegionalDiscovery.psm1`: Regional-Snapshots koennen jetzt `website_hint` und `career_hint` aus `data-jobagent-website`/`data-jobagent-career` oder JSON-Feldern uebernehmen. Relative URLs werden gegen die belegte Quellseite normalisiert; nur `http`/`https` wird akzeptiert. Jede Hint-Zeile enthaelt strukturierte `source_evidence` mit `source_id`, Quellseite, Record-ID, Beobachtungszeit und Content-Hash.
- `src/JobAgent.RegisterDiscovery.psm1`: Register-Snapshots transportieren optionale absolute `website_hint`-/`career_hint`-Felder und lehnen unsichere oder nicht absolute URLs fail-closed ab. Strukturierte Source-Evidence wurde ergaenzt.
- `src/JobAgent.JobBoardDiscovery.psm1`: Jobboard-Snapshots transportieren optionale Website-/Karrierehinweise aus HTML-Attributen, normalisieren relative Karrierepfade gegen die Jobboard-Basis-URL und lehnen unsichere Schemes ab. Strukturierte Source-Evidence wurde ergaenzt.
- `src/JobAgent.CompanyInventory.psm1`: `Update-JobAgentDiscoveryHintRetention` speichert `website_hint` und `career_hint` dauerhaft als `WEBSITE_HINT` bzw. `CAREER_HINT` in `discovered_urls`. Bestehende `observed_url`-Retention bleibt unveraendert.
- `tools/Measure-JobAgentDiscoverySourceInventory.ps1`: Die Quelleninventur zaehlt strukturierte URL-Hints insgesamt und je Quelle und zeigt die Werte in Samples.

Bereinigte Laufzeitdateien: durch Funktionstests erzeugte Aenderungen an `data/jobagent/company-candidate-verification.queue.json` und `html/jobagent/company-coverage.html` wurden vor dem Commit verworfen, damit keine faellige Retry-/HTML-Rotation als fachliche Aenderung mitgeht.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` -> Exit 0.

Kein Supertest in diesem Slice: Der Nutzer hat fuer diesen Chat keinen Supertest angefordert; gemaess Nutzeranweisung gilt er fuer diesen Zwischenabschluss als erledigt. JA-027 bleibt offen, daher kein Roadmap-Rotate.

## Offener Anschluss

Naechster priorisierter Schritt bleibt `JA-027.2`: automatischen Nachfuell-/Quellenwellen-Orchestrator bauen oder erweitern, der bei freiem Akquisebudget und fehlender startbarer Arbeit faellige erlaubte Snapshot-/Quelleninputs verarbeitet, neue Evidence gezielt reaktiviert, Freising-Fairness beachtet und je Lauf `logs/jobagent/JA-027-refill-<run-id>.json` schreibt.

Akzeptanz fuer den naechsten Slice:

- Kein globales Zuruecksetzen aller Reviewfaelle.
- Identischer Contenthash startet keinen neuen Versuch.
- Neue `website_hint`-/`career_hint`-Evidence oder faellige Retries reaktivieren nur betroffene Cluster.
- Gesperrte Quellen bleiben geparkt: Indeed `MANUAL_REVIEW_ONLY`, LinkedIn `REJECT`, HWK ohne Snapshotfreigabe, BioM ohne Snapshotvertrag, IHK ohne Export/API.
- Funktionstests zuerst: `Test-JobAgentDiscoverySourceInventory.ps1`, `Test-JobAgentCompanyCandidateVerification.ps1`, `Test-JobAgentCoverage.ps1` plus betroffene Adaptertests.
