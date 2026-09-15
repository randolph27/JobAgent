# Handoff latest

Stand: 2026-09-14T08:33:10+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand liefern`
- Branch: `master`
- HEAD vor Commit: `1248ab46ee60`
- Upstream: `origin/master`
- Roadmap-Rotation: keine Rotation. `JA-027` bleibt offen, weil das visuelle Viewport-Audit lokal blockiert ist.
- Supertest: gemaess aktueller Nutzerregel nicht als Blocker behandelt, weil er nicht separat angefragt wurde.
- STP: `cmd /c .\ci.cmd stp` -> Exit `0`

## Abgeschlossener Slice

`JA-027.3` wurde als Domain-/Hostwellen-Slice umgesetzt:

- Domain-only-Bestandsfirmen mit fehlender `career_url` werden in `src/JobAgent.Coverage.psm1` nicht mehr dauerhaft als `ALREADY_VERIFIED_IN_STORE`/`VERIFIED` aus der Arbeit entfernt.
- Solche Firmen werden mit `next_action = VERIFY_CAREER_SOURCE`, `status = PENDING` und `review_reason = PRODUCTIVE_COMPANY_NEEDS_OFFICIAL_CAREER_SOURCE` wieder startbar.
- `tools/Verify-JobAgentCompanyCandidates.ps1` akzeptiert `VERIFY_CAREER_SOURCE` als startbare Queue-Aktion.
- Die Kandidatenauswahl wird nicht mehr nach `HostConcurrency` gekuerzt. `HostConcurrency` bleibt Request-Concurrency-Policy; der logische Batch behaelt alle priorisierten Kandidaten.
- `logical_host_waves` protokolliert Hostgruppen und Wellen vor der HTTP-Arbeit.
- Batchmetriken trennen jetzt offizielle Karriere-/ATS-Erfolge von Domain-only-Erfolgen: `official_career_verified_total`, `domain_only_verified_total`, `official_career_verified_candidate_ids`, `domain_only_candidate_ids`.
- Wenn ein reiner Karrierequellen-Pruefauftrag erneut nur Domain-Erreichbarkeit bestaetigt, bleibt der Queueeintrag als `MANUAL_REVIEW_REQUIRED` mit `CAREER_SOURCE_MISSING_AFTER_DOMAIN_VERIFICATION` sichtbar und wird nicht als erledigte Karrierequelle gezaehlt.

## Geaenderte Dateien

- `Roadmap.md`
- `src/JobAgent.Coverage.psm1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `docs/handoffs/2026-09-13-ja0273-domain-hostwave-handoff.md`
- `todo.state.json`
- `todo.events.jsonl`
- `todo.checkpoint.json`
- `todo.history.digest.json`
- `todo.master.index.json`
- `handoff.latest.md`
- `handoff.latest.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`

## Blocker

- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `1`
- Fehler: lokaler Chrome-Headless-Abbruch bei 1920 px mit `GPU process isn't usable`.
- Gegenprobe mit zusaetzlichen Chrome-Flags hing ebenfalls. Edge wurde lokal nicht unter Standardpfad gefunden.

## Naechster Anker fuer neuen Chat

1. `tests/Test-JobAgentHtmlViewportAudit.ps1` stabilisieren oder eine alternative lokale Browser-Lane konfigurieren, ohne die visuellen Akzeptanzkriterien zu verwaessern.
2. Danach die JA-027-Abschlussabnahme ausfuehren: Funktionstests, Viewport-Audit, `.\ci.cmd route-check`, `.\ci.cmd stp`.
3. Wenn alle fachlichen Gates gruen sind, `JA-027` aus `Roadmap.md` nach `Roadmap_archive.md` rotieren und Todo/Handoff synchronisieren.
4. Danach erst zu `JA-041` wechseln: berufsneutrale Stellenerfassung von festen IT-Suchbegriffen und Profilpassung entkoppeln.
