# Handoff latest

Stand: 2026-09-15T13:25:34.584+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: `JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand liefern`
- Branch: `master`
- HEAD vor Handoff-Commit: `16cd6195e474`
- Upstream: `origin/master`
- Worktree: wird fuer Handoff-/STP-Commit bereinigt.
- Roadmap-Rotation: keine Rotation. `JA-027` bleibt offen, weil die Viewport-Audit-Lane lokal blockiert ist.
- Supertest: gemaess Nutzerregel nicht als Blocker behandelt, weil er nicht separat angefragt wurde.
- STP: `cmd /c .\ci.cmd stp` -> Exit `0`

## Letzter abgeschlossener Slice

`JA-027.3` wurde im Commit `16cd619` umgesetzt und nach `origin/master` gepusht:

- Domain-only-Bestandsfirmen mit fehlender `career_url` werden in `src/JobAgent.Coverage.psm1` nicht mehr dauerhaft als `ALREADY_VERIFIED_IN_STORE`/`VERIFIED` aus der Arbeit entfernt.
- Diese Firmen werden mit `next_action = VERIFY_CAREER_SOURCE`, `status = PENDING` und `review_reason = PRODUCTIVE_COMPANY_NEEDS_OFFICIAL_CAREER_SOURCE` wieder startbar.
- `tools/Verify-JobAgentCompanyCandidates.ps1` akzeptiert `VERIFY_CAREER_SOURCE` als startbare Queue-Aktion.
- `HostConcurrency` kuerzt keine Kandidatenauswahl mehr; es bleibt Request-Concurrency-Policy.
- `logical_host_waves` protokolliert Hostgruppen und Wellen vor der HTTP-Arbeit.
- Batchmetriken trennen offizielle Karriere-/ATS-Erfolge von Domain-only-Erfolgen: `official_career_verified_total`, `domain_only_verified_total`, `official_career_verified_candidate_ids`, `domain_only_candidate_ids`.
- Reine Karrierequellen-Pruefauftraege, die erneut nur Domain-Erreichbarkeit bestaetigen, bleiben als `MANUAL_REVIEW_REQUIRED` mit `CAREER_SOURCE_MISSING_AFTER_DOMAIN_VERIFICATION` sichtbar und werden nicht als erledigte Karrierequelle gezaehlt.

## Verifikation des abgeschlossenen Slice

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDiscoverySourceInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `cmd /c .\ci.cmd stp` -> Exit `0`
- `cmd /c .\ci.cmd route-check` -> Exit `0`

## Bekannter Blocker

- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `1`
- Fehler: Chrome Headless bricht lokal bei 1920 px mit `GPU process isn't usable` ab.
- Gegenprobe mit zusaetzlichen Chrome-Flags hing. Edge wurde lokal nicht unter Standardpfad gefunden.
- Der Blocker ist eine lokale Browser-/Viewport-Lane, kein fachlicher Supertest-Blocker.

## Neuer Chat: naechster Arbeitsanker

1. `tests/Test-JobAgentHtmlViewportAudit.ps1` stabilisieren oder eine alternative lokale Browser-Lane konfigurieren, ohne die visuellen Akzeptanzkriterien zu verwaessern.
2. Danach die JA-027-Abschlussabnahme ausfuehren: relevante Funktionstests, Viewport-Audit, `.\ci.cmd route-check`, `.\ci.cmd stp`.
3. Wenn alle fachlichen Gates gruen sind, `JA-027` aus `Roadmap.md` nach `Roadmap_archive.md` rotieren und Todo/Handoff synchronisieren.
4. Danach erst zu `JA-041` wechseln: berufsneutrale Stellenerfassung von festen IT-Suchbegriffen und Profilpassung entkoppeln.

## Priorisierte offene Aufgaben

- P1: Viewport-Audit-Lane reparieren. Startpunkt ist die Chrome-Headless-Konfiguration des HTML-Viewport-Tests bei 1920 px; Ziel ist ein reproduzierbar gruener visueller Audit fuer 390/800/1366/1920 px.
- P2: JA-027-Abschlussgate ausfuehren. Keine reale Firmenmindestmenge, aber Nachweis der Softwarefunktion: automatischer regulaerer Start, nachfuellbare Queue, Karrierequellen-Verifikation, sichtbarer WebIF-Bestand.
- P3: Roadmap-/Todo-Rotation erst nach gruener Abschlusslane. `TD-0041` bleibt bis dahin `in-progress`.
- P4: Nach Abschluss von JA-027 mit `TD-0053`/`JA-041` weitermachen.

## Wichtige Dateien fuer den Anschluss

- `Roadmap.md`
- `todo.current.md`
- `todo.state.json`
- `todo.events.jsonl`
- `handoff.latest.md`
- `handoff.latest.json`
- `docs/handoffs/2026-09-13-ja0273-domain-hostwave-handoff.md`
- `src/JobAgent.Coverage.psm1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `tests/Test-JobAgentHtmlViewportAudit.ps1`
