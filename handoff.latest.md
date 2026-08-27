# Handoff latest

Stand: 2026-08-27T06:58:05.835+02:00

## Abgeschlossen

JA-025 / TD-0039 ist abgeschlossen, per ./ci.cmd stp synchronisiert und nach Roadmap_archive.md rotiert.

Ergebnis:
- Alle aktuell erlaubten importierbaren Snapshot-Quellen wurden verarbeitet: source_gate.status=passed, xpected_sources_total=25, processed_sources_total=25.
- Neue Quelle: source-registry:openstreetmap_overpass_business_names.
- Neuer Snapshot: 	ests/fixtures/jobagent/regional-discovery/openstreetmap-overpass-business-names-snapshot.json.
- OSM-/Overpass-Hints: 1162 unverifizierte Arbeitgeberhinweise aus namentlich erfassten office=company-Elementen im Muenchen-/Freising-Zielgebiet.
- Kandidatenbasis: 	arget_inventory_candidates_total=1826, 	arget_inventory_gap_to_1000=0.
- Hint-/Queue-Stand: merged_hints_total=1790, candidate_verification_queue.clusters_total=1788, candidate_verification_queue.candidates_total=1790.
- Keine produktiven Store- oder JobSource-Writes aus Sekundaerquellen.

## Aktiver Anschluss

JA-027 / TD-0041 ist der einzige offene Roadmap-/Todo-Punkt.

Ziel: Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen.

Pflichtregeln:
- Keine produktive Firma ohne offiziellen Website-, Karriere- oder ATS-Beleg.
- Jobboersen, Arbeitsagentur, Register, OSM und regionale Verzeichnisse bleiben Discovery-/Review-Hinweise.
- Keine Bewerbungen, keine Formularaktionen, kein Login/Captcha/Paywall-Bypass.
- Unklare Kandidaten fail-closed in MANUAL_REVIEW_REQUIRED, NO_CAREER_PAGE_FOUND, RETRY_REQUIRED, BLOCKED, DUPLICATE oder OUT_OF_SCOPE belassen.

Naechste Arbeitsschritte:
1. data/jobagent/company-candidate-verification.queue.json priorisieren; nicht direkt aus company-discovery.hints.json in den Store schreiben.
2. Kleine Verifikationswelle starten, statt alle 1788 Cluster ungefiltert live zu pruefen.
3. Pro Kandidat offizielle Website, Domain-/Impressumsbezug, Karrierepfad oder offiziell verlinkten ATS-Mandanten pruefen.
4. Nur COMPANY_DOMAIN_VERIFIED, CAREER_URL_VERIFIED oder OFFICIAL_ATS_VERIFIED duerfen produktiv in data/jobagent/store.json/JobSources uebernommen werden.
5. Report und Coverage nach jeder Teilwelle aktualisieren, inklusive nicht uebernommener Kandidaten und Reject-/Review-Gruenden.

Relevante Module/Tools:
- 	ools/Verify-JobAgentCompanyCandidates.ps1
- 	ools/Import-JobAgentCompanyDiscovery.ps1
- 	ools/Measure-JobAgentCompanyCoverage.ps1
- src/JobAgent.SourceVerification.psm1
- src/JobAgent.SourceAdapters.psm1
- src/JobAgent.LiveScan.psm1
- src/JobAgent.CompanyInventory.psm1
- src/JobAgent.Coverage.psm1

## Verifikation

- pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1 -> Exit 0
- pwsh -NoProfile -File .\tools\Import-JobAgentCompanyDiscovery.ps1 -SnapshotLane -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1 -> Exit 0
- pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1 -> Exit 0
- pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1 -> Exit 0
- curl.exe -sS http://localhost:9000/api/system/status -> Exit 0, SonarQube UP
- .\ci.cmd stp -> Exit 0

Supertest wurde nicht erneut ausgefuehrt; gemaess aktueller Nutzeranweisung gilt der nicht separat angefragte Supertest fuer diesen Abschluss als erledigt.
