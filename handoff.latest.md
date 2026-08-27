# Handoff latest

Stand: 2026-08-27T07:10:22.973+02:00

## Aktiver Roadmap-/Todo-Stand

- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`.
- Offenes Todo: `TD-0041`.
- Der Roadmap-Punkt ist nicht komplett erledigt und wurde deshalb nicht nach `Roadmap_archive.md` rotiert.
- Supertest gilt gemaess Nutzeranweisung als erledigt, auch wenn in dieser Arbeitswelle nur funktionsbezogene Tests ausgefuehrt wurden.

## Umgesetzter Arbeitsschritt

- `tools/Verify-JobAgentCompanyCandidates.ps1` nutzt fuer Verifikationswellen jetzt die angereicherte Coverage-Review-Queue aus `New-JobAgentCoverageCandidateReviewQueue`.
- Die Verifikationswelle priorisiert Kandidaten mit verwertbarer offizieller Domain bzw. bestehendem Company-Bezug vor reinen Namenshinweisen.
- Queue-Felder wie `next_action`, `reason_codes`, `source_evidence`, `dedupe_context`, `freshness_status` und `risk_level` bleiben beim Update erhalten.
- Produktive Firmen-Upserts ueberschreiben vorhandene `career_url` nicht mehr blind, wenn bereits eine gepflegte Karriere-URL vorhanden ist.
- `src/JobAgent.SourceVerification.psm1` prueft Karriere-Link-Treffer strenger: Suchmuster muessen als Token statt als beliebiger Substring passen, und offizielle Firmenlinks werden nur als Karriere-Kandidaten akzeptiert, wenn auch Host/Pfad einen Karrierebezug enthaelt.
- `tests/Test-JobAgentSourceVerification.ps1` enthaelt neue Assertions fuer diese False-Positive-Faelle.

## Produktiver Datenstand nach der Welle

- Kandidatenqueue: `data/jobagent/company-candidate-verification.queue.json`
  - `clusters_total`: 1788
  - `candidates_total`: 1790
  - `VERIFIED`: 5
  - `MANUAL_REVIEW_REQUIRED`: 3
  - `PENDING`: 1780
- Store: `data/jobagent/store.json`
  - Firmen gesamt: 38
  - JobSources gesamt: 43
  - Keine ungeprueften Register-/Regional-/OSM-Hints wurden produktiv in Firmen oder JobSources uebernommen.

## Live-Verifikationswelle

Command:

```powershell
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 9 -TimeoutSeconds 8 -MaxRetries 3
```

Ergebnis:

- `processed_total`: 9
- `productive_upsert_allowed_total`: 5
- `manual_review_total`: 4
- `fail_closed_reject_total`: 0
- Log: `logs/jobagent/company-candidate-verification-20260827-050812.json`

Produktiv verifiziert:

- `jobboard-hint:ba_jobsuche_flughafen_muenchen_it_operations_muenchen` -> `company:flughafen_muenchen_gmbh`, `CAREER_URL_VERIFIED`, Beleg `https://munich-airport.com/careers-15404919`
- `jobboard-hint:stepstone_muenchen_rohde_and_schwarz_it_operations_muenchen` -> `company:rohde_and_schwarz_gmbh_and_co_kg`, `CAREER_URL_VERIFIED`, Beleg `https://rohde-schwarz.com/de/karriere/stellenangebote/karriere-stellenangebote_251573.html`
- `jobboard-hint:stepstone_muenchen_siemens_it_operations_muenchen` -> `company:siemens_ag`, `CAREER_URL_VERIFIED`, Beleg `https://siemens.com/en-us/company/jobs`
- `jobboard-hint:ba_jobsuche_stadtwerke_muenchen_it_operations_muenchen` -> `company:stadtwerke_muenchen_gmbh`, `CAREER_URL_VERIFIED`, Beleg `https://swm.de/karriere/jobboerse?id=31526&stellenanzeige=Ingenieur*in-fuer-die-E/MSR-und-Leittechnik-fuer-Anlagen-der-Tiefen-Geothermie-(m/w/d)`
- `hint:indeed_de_cancom_director_it_muenchen` -> `company:cancom_se`, `CAREER_URL_VERIFIED`, Beleg `https://karriere.cancom.de/`

Fail-closed in Manual Review:

- `register-hint:offeneregister_sample_2026_08_alpha_technik_gmbh_muenchen_1`
- `regional-hint:stadt_muenchen_unternehmensbeteiligungen_aquabench_gmbh_muenchen`
- `regional-hint:stadt_freising_weihenstephan_bayerische_landesanstalt_fuer_landwirtschaft_freising_weihenstephan`
- `regional-hint:stadt_freising_weihenstephan_bayerische_landesanstalt_fuer_wald_und_forstwirtschaft_freising_weihenstephan`

Grund jeweils: `OFFICIAL_COMPANY_DOMAIN_MISSING`.

## Aktualisierte Artefakte

- `data/jobagent/store.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`
- `logs/jobagent/company-candidate-verification-20260827-050812.json`
- `logs/jobagent/company-coverage-20260827-050834.json`
- `logs/jobagent/company-coverage-20260827-050834.md`
- `todo.checkpoint.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Validierung

Ausgefuehrt und erfolgreich:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
.\ci.cmd stp
```

SonarQube: `curl.exe -sS http://localhost:9000/api/system/status` war erfolgreich, Status `UP`.

Devserver: `.\ci.cmd devserver-status` war erfolgreich, URL `http://localhost:8500/`.

## Bekannte Risiken

- Die Live-Verifikationslogik ist heuristisch. Sie prueft offizielle Domain, Linkbezug und HTTP-Erreichbarkeit, ersetzt aber keine menschliche Fachpruefung bei unklarer Marken-/Konzernstruktur.
- Viele Kandidaten aus Register-, Regional- und OSM-Quellen haben aktuell keinen offiziellen Domain-Hinweis und muessen fail-closed bleiben, bis eine belastbare Website-Ermittlung implementiert ist.
- `self-check` meldete vor dieser Arbeitswelle noch historische Handoff-/Immutable-Invarianten; `stp` wurde erfolgreich ausgefuehrt, aber ein neuer Agent sollte bei Bedarf `.\ci.cmd self-check` erneut ausfuehren und die verbleibenden Invarianten gezielt pruefen.

## Naechste konkrete Aufgaben

1. Fuer JA-027 eine Domain-Ermittlungsstufe fuer Kandidaten ohne `known_company_domain` bauen: Quelle `data/jobagent/company-candidate-verification.queue.json`; Ziel offizielle Website-Kandidaten mit Impressum-/Namens-/Standortbezug; fail-closed kein produktiver Upsert ohne offiziellen Beleg.
2. Danach eine weitere kleine Verifikationswelle ausfuehren: Start mit `MaxCandidates 10-25`, nicht direkt alle 1788 Cluster live pruefen; Ergebnisse in `logs/jobagent/company-candidate-verification-*.json` pruefen.
3. Coverage aktualisieren: `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250`; `html/jobagent/company-coverage.html` auf sichtbare Review-/Verified-Zahlen pruefen.
4. Funktionstests ausfuehren: `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1`.
5. JA-027 erst abschliessen und rotieren, wenn alle Akzeptanzbedingungen aus `Roadmap.md` belegt sind: offizielle Website-/Karriere-/ATS-Evidenz pro produktiv hinzugefuegter Firma, nicht uebernommene Kandidaten mit Review-/Reject-Grund, Coverage-/Report-Artefakte aktualisiert, Funktions- und Abschluss-Gates gruen.

## Git-Anker vor Commit

- Branch: `master`
- HEAD vor Commit: `ae7dfe9aa382`
- Upstream: `origin/master`
- Ahead/Behind vor Commit: `0/0`
