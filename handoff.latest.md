# Handoff latest

Stand: 2026-08-28T13:45:29.164+02:00

## Neuer-Chat-Start

- Projektpfad: D:\_Scripte\JobAgent
- Repo: https://github.com/randolph27/JobAgent
- Branch: master
- HEAD vor Abschluss-Commit: 3d238dde4e20
- Offener Roadmap-Punkt: JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen
- Offenes Todo: TD-0041, Status open, active_id=null
- Roadmap-Rotation: nicht ausgefuehrt; JA-027 ist fachlich nicht abgeschlossen.
- Supertest: nicht neu ausgefuehrt; gemaess Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt.
- Devserver: http://localhost:8500/, Status zuletzt listening=True, PID 23568
- SonarQube: http://localhost:9000/api/system/status, Status zuletzt UP, Version 26.1.0.118079

## Letzter abgeschlossener Arbeitsschritt

- Fuer JA-027 wurde die Website-Discovery-Queue der aktuell selektierten Kandidaten vollstaendig abgearbeitet.
- Drei Discovery-Laeufe wurden ausgefuehrt: 50, 250 und 336 Kandidaten.
- Ergebnis der Wellen: 636 Kandidaten verarbeitet, 0 offizielle Website-Treffer, 636 fail-closed in MANUAL_REVIEW_REQUIRED, 0 produktive Store-Upserts.
- Die zuvor noch unversuchten DISCOVER_OFFICIAL_WEBSITE-Queue-Eintraege sind jetzt 0.
- Hauptgrund: Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen. Betroffene Discovery-Hints bleiben ausserhalb des produktiven Stores.
- Kandidatenverifikation wurde ausgefuehrt, verarbeitete aber 0 Kandidaten, weil ready_total=0 ist.
- Coverage wurde neu erzeugt: logs/jobagent/company-coverage-20260828-114037.json, logs/jobagent/company-coverage-20260828-114037.md, html/jobagent/company-coverage.html.
- STP wurde am 2026-08-28T13:45:29.164+02:00 ausgefuehrt.

## Datenstand nach Coverage und Queue

- Produktive Firmen: 85
- Target-Inventory-Kandidaten: 1870
- Target-Inventory-Gate: failed
- Import Waves: 4
- Queue-Cluster: 1785
- Queue-Kandidaten: 1790
- Queue ready_total: 0
- Queue DISCOVER_OFFICIAL_WEBSITE unversucht: 0
- Queue VERIFIED: 53
- Queue RETRY_SCHEDULED: 8
- Queue MANUAL_REVIEW_REQUIRED: 1724

## Verifikation

- ./ci.cmd devserver-status -> Exit 0; Port 8500 listening True
- curl.exe -s http://localhost:9000/api/system/status -> Exit 0; Status UP; Version 26.1.0.118079
- pwsh -NoProfile -File ./tools/Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 50 -TimeoutSeconds 8 -> Exit 0; 50 verarbeitet; 0 verified; 50 Manual Review
- pwsh -NoProfile -File ./tools/Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 250 -TimeoutSeconds 8 -> Exit 0; 250 verarbeitet; 0 verified; 250 Manual Review
- pwsh -NoProfile -File ./tools/Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 400 -TimeoutSeconds 8 -> Exit 0; 336 verarbeitet; 0 verified; 336 Manual Review
- pwsh -NoProfile -File ./tools/Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 20 -TimeoutSeconds 8 -MaxRetries 3 -> Exit 0; processed_total 0; ready_total 0
- pwsh -NoProfile -File ./tools/Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250 -> Exit 0; Coverage aktualisiert; target_inventory_gate_status=failed
- pwsh -NoProfile -File ./tests/Test-JobAgentCompanyCandidateVerification.ps1 -> Exit 0; 24 Faelle bestanden
- pwsh -NoProfile -File ./tests/Test-JobAgentCoverage.ps1 -> Exit 0; 28 Faelle bestanden
- ./ci.cmd route-check -> Exit 0
- ./ci.cmd stp -> Exit 0

## Dateien fuer Abschluss-Commit

-  M data/jobagent/company-candidate-verification.queue.json
-  M data/jobagent/company-discovery.hints.json
-  M data/jobagent/store.json
-  M handoff.latest.json
-  M handoff.latest.md
-  M todo.events.jsonl
-  M todo.history.digest.json
-  M todo.master.index.json

## Naechste Aufgaben fuer den neuen Chat

1. JA-027 Hotspot fachlich wechseln: Es gibt keine unversuchten DISCOVER_OFFICIAL_WEBSITE-Eintraege mehr. Der naechste Fortschritt braucht eine zulaessige offizielle Website-Ermittlungsquelle fuer die 1724 Manual-Review-Hints.
2. Keine weiteren produktiven Store-Upserts erzwingen. Kandidaten ohne offiziellen Website-/Karriere-/ATS-Beleg bleiben fail-closed in MANUAL_REVIEW_REQUIRED oder RETRY_SCHEDULED.
3. Moegliche naechste Umsetzung: Source-Registry und Importlogik so erweitern, dass belastbare offizielle Verzeichnisse oder Registerquellen mit Firmenwebsite-Link als SECONDARY_OFFICIAL_DIRECTORY/PRIMARY_OFFICIAL eingebunden werden. Keine Jobboersen, OSM-Listen oder GitHub-Listen als Primaerbeleg verwenden.
4. Danach Discover-JobAgentCompanyCandidateWebsites.ps1 erneut gegen die zulaessigen Quellen laufen lassen.
5. Sobald ready_total groesser 0 ist, Verify-JobAgentCompanyCandidates.ps1 ausfuehren und nur Kandidaten mit COMPANY_DOMAIN_VERIFIED, CAREER_URL_VERIFIED oder OFFICIAL_ATS_VERIFIED upserten.
6. Danach Coverage aktualisieren und die fokussierten Funktionstests Test-JobAgentCompanyCandidateVerification.ps1 und Test-JobAgentCoverage.ps1 ausfuehren. Supertest erst nach Roadmap-Abschluss oder ausdruecklicher Anforderung; laut Nutzer gilt nicht angefragter Supertest als erledigt.
7. Am Ende Route-Check, STP, Stage, Commit und Push wiederholen.

## Guardrails

- Offizielle Quellen sind zwingend. Jobboersen, Arbeitsagentur, Register, OSM-Listen und andere Hints bleiben Discovery-Hinweise und duerfen keine primaere Karrierequelle ersetzen.
- Kandidaten ohne eindeutigen offiziellen Website-/Karriere-/ATS-Beleg muessen fail-closed in Review/Retry bleiben.
- Keine automatische Bewerbung, keine extern wirksame Aktion, keine erfundenen Firmen, URLs oder Job-IDs.
