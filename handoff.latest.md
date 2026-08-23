# Handoff latest

Stand: 2026-08-23T11:12:00.000+02:00

## Ziel fuer neuen Chat

Direkt mit `TD-0028` / `JA-028` weitermachen: Offizielle Firmenwebsite-, Karriere- und ATS-Verifikation fuer deduplizierte Kandidaten automatisieren. Keine erneute Arbeit an JA-027 starten; JA-027 ist abgeschlossen und archiviert.

## Aktueller Zustand

- Active: `TD-0028`
- Status: `in-progress`
- Branch: `master`
- Letzter lokaler HEAD vor Commit: `6ee717f4c210`
- Roadmap aktiv: JA-028, JA-029, JA-030
- Abgeschlossen und rotiert: JA-027 Deduplikation, Standortlogik und Kandidatenqualitaet fuer tausende Firmen skalieren
- STP zuletzt ausgefuehrt: `.\ci.cmd stp` am 2026-08-23T11:09:04+02:00, Exit 0

## Was in JA-027 erledigt wurde

JA-027 ist fachlich abgeschlossen. Die Kandidaten-Deduplikation verdichtet Register-, Jobboersen- und Regional-Hints zu stabilen Identitaetsclustern. Reine Namensgleichheit fuehrt nicht zu automatischem Merge, sondern zu Review-Konflikten. Starke Identitaetskeys sind Domain, Register-ID und Company-ID. Personaldienstleister, unsichere Zielgebiete und Out-of-Scope-Hints werden markiert und bleiben auditierbar.

Implementiert:

- `src/JobAgent.CompanyInventory.psm1`
  - `ConvertTo-JobAgentCompanyCandidateRecord`
  - `Resolve-JobAgentCompanyCandidateClusters`
  - `target_area_basis`: `REGISTER_SEAT_IN_TARGET`, `JOB_LOCATION_IN_TARGET`, `BRANCH_HINT_IN_TARGET`, `REMOTE_WITH_TARGET_REFERENCE`, `TARGET_UNCERTAIN`, `OUT_OF_SCOPE`
  - Konfliktflags: `NAME_MATCH_WITHOUT_STRONG_IDENTITY`, `STAFFING_AGENCY_REVIEW`, `TARGET_AREA_UNCERTAIN`, `OUT_OF_SCOPE_HINT`
- `src/JobAgent.Coverage.psm1`
  - `New-JobAgentCoverageCandidateClusterReport`
  - Kandidatencluster-Metriken in `New-JobAgentCoverageReport`
  - Dimensionen fuer Standortbasis, Konfliktflags und Review-Queue-Gruende
- `tools/Measure-JobAgentCompanyCandidateDedupe.ps1`
  - erzeugt `logs/jobagent/company-candidate-dedupe-*.json`
  - erzeugt `logs/jobagent/company-candidate-dedupe-*.md`
  - erzeugt `logs/jobagent/company-discovery-hints-clustered-*.json`
- `tools/Measure-JobAgentCompanyCoverage.ps1`
  - HTML-/Markdown-Coverage enthaelt Kandidaten-Dedupe-Abschnitt
  - neue Metriken: `candidate_clusters_total`, `candidate_conflict_clusters`, `candidate_review_queue_total`
- `tests/Test-JobAgentCompanyDedupeScale.ps1`
  - 5.008 Kandidaten, 5.006 Cluster, stabile IDs und Laufzeitgrenze
- `tests/Test-JobAgentCoverage.ps1`
  - prueft Cluster-Metriken, Review-Queue, Dedupe-Tool-Artefakte und HTML-Guards
- `tests/Test-JobAgentSupertest.ps1`, `tests/Test-JobAgentTestMatrix.ps1`, `docs/test-matrix.json`, `docs/test-matrix.md`
  - JA-027 ist in Matrix und Supertest enthalten

## Verifikation

Grün:

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0
- `pwsh -NoProfile -File tools\Measure-JobAgentCompanyCandidateDedupe.ps1` -> Exit 0; produktiver Hint-Store: 19 Kandidaten, 18 Cluster, 2 Konfliktcluster, 6 Review-Queue-Cluster
- `.\ci.cmd supertest` -> Exit 0
- `.\ci.cmd stp` -> Exit 0

Nicht grün / Betriebsblocker:

- SonarQube: `Invoke-RestMethod http://localhost:9000/api/system/status` lief in Timeout.
- `.\ci.cmd sonar-start` schlug fehl: lokaler Wrapper `D:\_Scripte\JobAgent\sonar.cmd` fehlt.
- Es wurde kein Sonar-Server gestartet. Fuer neuen Chat: erst `sonar.cmd`/Projektwrapper klaeren oder vorhandenen Sonar-Portproxy separat reparieren.

## Aktive Aufgaben fuer neuen Chat

### TD-0028 / JA-028 starten

Ziel: Kandidaten aus dem deduplizierten Hint-Store nur dann produktiv nutzbar machen, wenn offizielle Firmenwebsite-, Karriere- oder ATS-Belege vorhanden sind.

Konkreter naechster Schnitt:

1. Bestehende Verifikationslogik in `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.LiveScan.psm1`, `src/JobAgent.CompanyInventory.psm1` und `tools/Verify-JobAgentCompanyCareers.ps1` pruefen.
2. Neues oder erweitertes Tool bauen, wahrscheinlich `tools/Verify-JobAgentCompanyCandidates.ps1`, das Cluster aus `data/jobagent/company-discovery.hints.json` oder aus dem Dedupe-Report verarbeitet.
3. Queue-Felder modellieren: Kandidatenprioritaet, Retry, `expires_at`, `observed_at`, `verified_by_url`, `verification_url`, `redirect_chain`, `http_status`, `final_url`, `evidence_type`, `evidence_text_hash`, `reason`.
4. Fail-closed Status implementieren: `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED`, `OFFICIAL_ATS_VERIFIED`, `MANUAL_REVIEW_REQUIRED`, `UNVERIFIED`.
5. Produktiven Upsert begrenzen: keine neue `company` und keine `job_source`, solange nur Jobboerse/Register/Regionalhint ohne offiziellen Firmenbeleg vorliegt.
6. Funktionstest zuerst: `tests/Test-JobAgentCompanyCandidateVerification.ps1`; danach bestehende Tests `tests/Test-JobAgentSourceVerification.ps1` und `tests/Test-JobAgentLiveScan.ps1` erweitern.
7. Supertest erst am Abschluss von JA-028 laufen lassen; laut Nutzeranweisung gilt ein nicht separat angefragter Supertest nicht als Blocker, aber fuer Roadmap-Abschluss wurde er bisher trotzdem ausgefuehrt.

### Danach offen

- TD-0029 / JA-029: Produktive Erweiterungswellen mit Coverage-Gates.
- TD-0030 / JA-030: Laufender Coverage-Betrieb, Drift-Erkennung und Quellen-Freshness.

## Wichtige Regeln fuer neuen Chat

- Deutsch antworten.
- Keine Jobboerse, kein Registerdump und keine regionale Liste als offizielle Karrierequelle verwenden.
- Keine Bewerbung, kein Login, kein Captcha-Bypass, kein Kontaktformular.
- Keine erfundenen Unternehmen, URLs, Jobs, Geodaten oder Verifikationsaussagen.
- Funktionsbezogene Tests zuerst; Supertest erst bei abgeschlossenem Roadmap-Punkt.
- Devserver ueber `.\ci.cmd` auf Port `8500`; SonarQube nur ueber `.\ci.cmd`/API/Curl, aber aktueller Wrapper fehlt.



