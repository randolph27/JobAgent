# Handoff latest

Stand: 2026-08-23T11:19:59.535+02:00

## Ziel fuer neuen Chat

Direkt mit `TD-0028` / `JA-028` weitermachen. JA-028 ist noch nicht komplett abgeschlossen und wurde daher nicht aus `Roadmap.md` rotiert. Der neue Agent soll nicht mit JA-029 starten, auch wenn das letzte automatische STP-Feld faelschlich JA-029 als naechsten Anker ausgegeben hat.

## Aktueller Zustand

- Active: `TD-0028`
- Status: `in-progress`
- Branch: `master`
- HEAD vor Commit/Push: `0ea28d3602f5`
- Roadmap aktiv: JA-028, JA-029, JA-030
- Supertest: laut Nutzeranweisung fuer diesen Zwischenstand nicht erforderlich; funktionsbezogene Tests sind massgeblich.
- Roadmap-Rotation: keine Rotation, weil JA-028 nur teilweise umgesetzt ist.

## Erledigter Arbeitsschnitt in JA-028

Implementiert ist die erste produktionsnahe Kandidatenverifikations-Lane fuer deduplizierte Discovery-Hints. Sie validiert Kandidaten nur gegen offizielle Firmen-/Karriere-/ATS-Belege und bleibt fail-closed, wenn ein offizieller Beleg fehlt.

Geaendert:

- `src/JobAgent.SourceVerification.psm1`
  - neue Funktion `Resolve-JobAgentCompanyCandidateVerification`
  - Candidate-Stubs aus `known_company_id` und `known_company_domain`
  - Statusmodell fuer Kandidaten: `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED`, `OFFICIAL_ATS_VERIFIED`, `MANUAL_REVIEW_REQUIRED`, `UNVERIFIED`
  - Evidence-Objekte mit `verification_url`, `verified_by_url`, `redirect_chain`, `evidence_type`, `evidence_text_hash`, `observed_at`, `http_status`, `final_url`, `reason`, `expires_at`
  - Aggregator-Links bleiben ausgeschlossen; Jobboersen reichen nie als offizielle Quelle
  - fehlende offizielle Domain, unsicherer Zielraum und Personaldienstleister fuehren zu Review beziehungsweise Fail-closed-Verhalten
- `src/JobAgent.Persistence.psm1`
  - Store-Validierung akzeptiert `OFFICIAL_ATS_VERIFIED`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
  - liest `data/jobagent/company-discovery.hints.json`
  - verarbeitet Kandidaten priorisiert und limitiert
  - schreibt `logs/jobagent/company-candidate-verification-*.json`
  - upsertet nur offiziell verifizierte Firmen und offizielle JobSources
  - bietet `-FixtureMapPath` fuer deterministische Funktionstests ohne Live-Web
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
  - deckt Karriere-URL-Verifikation, offizielle ATS-Verifikation, reine Firmendomain, fehlende Domain, Aggregator-Ablehnung und Tool-Upsert ab

## Verifikation

Gruen:

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `.\ci.cmd stp` -> Exit 0

Nicht ausgefuehrt:

- `.\ci.cmd supertest`; Nutzer hat fuer diesen Zwischenstand festgelegt, dass ein nicht angefragter Supertest als erledigt gilt.

Bekannte Blocker/Risiken:

- `.\ci.cmd self-check` lief vor diesem STP mit Exit 1; Log: `logs\terminal\self-check-20260823-111326.log`
- SonarQube auf `:9000` antwortete innerhalb 5 Sekunden nicht; lokaler `sonar.cmd`/Portproxy ist separat zu klaeren.
- `.\ci.cmd stp` referenziert weiterhin einen alten `verify.digest.json` mit laufendem Gradle-Verify; das gehoert nicht zu diesem Funktionsschnitt.

## Naechste Aufgaben fuer neuen Chat

1. JA-028 fortsetzen: Candidate-Verification-Queue auf Cluster-Ebene bauen, damit `identity_cluster_id`, Kandidatenprioritaet, Retry, `expires_at`, `observed_at`, naechster Versuch und Review-Grund stabil persistiert werden.
2. Produktiven Upsert weiter haerten: nur `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED` und `OFFICIAL_ATS_VERIFIED` duerfen Firmen anlegen/aktualisieren; JobSources nur bei Karriere- oder ATS-Beleg.
3. Coverage-/Review-Report integrieren: verifizierte, unverifizierte, manuelle Review- und Reject-Faelle in Coverage-JSON/Markdown/HTML sichtbar machen.
4. Tests erweitern: `tests\Test-JobAgentCompanyCandidateVerification.ps1` um Retry/Ablauf/Cluster-Queue, falsche Domain, Timeout, 404 und JavaScript-only-Fall erweitern; bestehende SourceVerification-/LiveScan-Tests synchron halten.
5. Erst wenn JA-028 fachlich komplett ist: Testmatrix/Supertest aktualisieren, `.\ci.cmd supertest` ausfuehren, Roadmap-Punkt nach `Roadmap_archive.md` rotieren und Todo/Handoff final konsolidieren.
