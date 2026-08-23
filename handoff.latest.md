# Handoff latest

Stand: 2026-08-23T11:30:17.300+02:00

## Ziel fuer neuen Chat

Direkt mit `TD-0028` / `JA-028` weitermachen. Nicht mit JA-029 starten: der automatisch erzeugte STP-Anker nennt JA-029, fachlich ist JA-028 aber noch `in-progress`.

## Aktueller Zustand

- Active: `TD-0028`
- Status: `in-progress`
- Branch: `master`
- HEAD vor Commit/Push: `2297711334a6`
- Roadmap aktiv: JA-028, JA-029, JA-030
- Roadmap-Rotation: keine Rotation, weil JA-028 noch nicht vollstaendig abgeschlossen ist.
- Supertest: nicht ausgefuehrt; laut aktueller Nutzeranweisung gilt ein nicht angefragter Supertest fuer diesen Uebergabestand als erledigt.
- STP: `.\ci.cmd stp` lief erfolgreich mit Exit 0 am 2026-08-23T11:30:17+02:00.

## Erledigter Arbeitsschnitt in JA-028

Die Candidate-Verification-Lane hat jetzt eine persistente Cluster-/Retry-Queue und bleibt beim produktiven Upsert fail-closed.

Geaendert:

- `tools/Verify-JobAgentCompanyCandidates.ps1`
  - neue Queue-Datei `data/jobagent/company-candidate-verification.queue.json`
  - Queue-Eintraege enthalten `identity_cluster_id`, `candidate_ids`, `canonical_name`, `source_count`, `priority_score`, `target_area_basis`, `status`, `review_reason`, `retry_count`, `last_attempt_at`, `next_attempt_at`, `last_status`, `last_reason`
  - Kandidaten werden nach Cluster-Prioritaet und faelligem `next_attempt_at` verarbeitet
  - `VERIFIED`, `MANUAL_REVIEW_REQUIRED`, `RETRY_SCHEDULED` und `RETRY_EXHAUSTED` werden getrennt persistiert
  - produktiver Firmen-Upsert bleibt auf `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED`, `OFFICIAL_ATS_VERIFIED` begrenzt
  - JobSources werden weiterhin nur bei `CAREER_URL_VERIFIED` oder `OFFICIAL_ATS_VERIFIED` angelegt
- `src/JobAgent.SourceVerification.psm1`
  - Known-Domain-Mismatch gegen eine bestehende Firma wird als `KNOWN_COMPANY_DOMAIN_MISMATCH` in Manual Review gezwungen
- `src/JobAgent.Coverage.psm1`
  - `New-JobAgentCoverageReport` nimmt optional `CandidateVerificationQueue`
  - Coverage-Metriken zaehlen Queue gesamt, bereit/retry, verifiziert, Manual Review und Retry exhausted
- `tools/Measure-JobAgentCompanyCoverage.ps1`
  - liest optional `data/jobagent/company-candidate-verification.queue.json`
  - JSON/Markdown/HTML enthalten Queue-Metriken und eine Tabelle `Kandidaten-Verifikationsqueue`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
  - erweitert um falsche Domain, Timeout, 404, JavaScript-only-Domain-only und Cluster-Queue mit Retry/Review
- `tests/Test-JobAgentCoverage.ps1`
  - erweitert um Queue-Metriken und Coverage-HTML/Markdown-Assertions
- `html/jobagent/company-coverage.html`
  - lokales Coverage-HTML wurde durch den Coverage-Test neu erzeugt

## Verifikation

Gruen:

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0
- `.\ci.cmd stp` -> Exit 0

Nicht ausgefuehrt:

- `.\ci.cmd supertest`; fuer diesen Uebergabestand nicht angefragt und laut Nutzeranweisung als erledigt zu behandeln.

## Offene Aufgaben fuer neuen Chat

1. JA-028 abschliessen: Review-/Reject-Report aus echten Verifikationslaeufen konsistent in Coverage, Logs und Handoff-Evidence verwenden.
2. Pruefen, ob JA-028-Akzeptanz vollstaendig erfuellt ist: offizielle Domain, falsche Domain, ATS mit/ohne Firmenbeleg, Redirects, JavaScript-only, Timeout, 404 und Review-Queue sind funktional getestet; offen ist vor allem die finale Abschlusskonsolidierung.
3. Erst wenn JA-028 fachlich komplett ist: Testmatrix/Supertest aktualisieren, Roadmap-Punkt nach `Roadmap_archive.md` rotieren und Todo auf JA-029 weiterstellen.
4. Danach mit JA-029 starten: produktive Erweiterungswellen mit Coverage-Gates.

## Hinweise

- `todo.events.jsonl`, `todo.history.digest.json` und `todo.master.index.json` wurden durch `.\ci.cmd stp` aktualisiert.
- STP schreibt im generierten Feld `next` faelschlich JA-029, obwohl TD-0028 noch aktiv ist. Fuer den neuen Chat ist dieser Handoff-Text massgeblich.
