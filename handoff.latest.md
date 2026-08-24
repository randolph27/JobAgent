# Handoff latest

Stand: 2026-08-24T08:30:00+02:00

## Neuer Chat Einstieg

Direkt mit `TD-0032 / JA-032` weitermachen: Coverage-HTML und Coverage-Markdown sollen die in JA-031 erzeugten Linkobjekte sichtbar als anklickbare Anbieter-, Karriere- und ATS-Links rendern.

## Aktueller Zustand

- Projekt: `JobAgent`
- Root: `D:\_Scripte\JobAgent`
- Branch: `master`
- HEAD: `3e26b7311c6a`
- Upstream: `origin/master`
- Active: `TD-0032`
- Offen: `TD-0032 / JA-032`, danach `TD-0033 / JA-033`
- Abgeschlossen und rotiert: `JA-031 Anbieter-Link-Vertrag fuer Coverage- und Daily-Reports definieren`
- Roadmap: `JA-031` liegt in `Roadmap_archive.md`; `Roadmap.md` enthaelt nur noch `JA-032` und `JA-033`
- Todo: `todo.current.md` zeigt `TD-0032` als Active

## Was erledigt ist

JA-031 ist fachlich abgeschlossen:

- `src/JobAgent.Coverage.psm1` enthaelt `Get-JobAgentCoverageCompanyLinks`.
- `New-JobAgentCoverageReport` liefert pro Firma `links` und `primary_link`.
- Linktypen: `career`, `website`, `ats`, `review_hint`, `missing`.
- Linkfelder: `link_type`, `label`, `url`, `source_id`, `source_field`, `verification_status`, `is_primary`, `is_clickable`, `review_only`, `reason`.
- Offizielle Links kommen nur aus `company.career_url`, `company.official_website_url` oder offiziellen `job_sources.canonical_url`.
- Unverifizierte `discovery_source.url` erscheint nur als `review_hint` und nicht produktiv klickbar.
- Unoffizielle Jobboersen-Hints werden nicht als Anbieterlink uebernommen.
- Fehlende offizielle Links werden fail-closed als `missing` mit Grund markiert.
- `schemas/jobagent.schema.json` dokumentiert `$defs.coverage_link`.
- `docs/company-discovery-operations.md` dokumentiert den Anbieter-Link-Vertrag.
- `tests/Test-JobAgentCoverage.ps1` prueft Karriere-URL, Website-only, offizielle ATS-Quelle, Review-Hint, Missing-Link und Ausschluss unoffizieller Jobboersenlinks.

## Naechste Aufgabe TD-0032 / JA-032

Umzusetzen:

1. In `tools/Measure-JobAgentCompanyCoverage.ps1` Renderer-Helfer fuer Linkobjekte ergaenzen.
2. Markdown-Link nur fuer `is_clickable=true` ausgeben.
3. HTML-Link mit `target="_blank"` und `rel="noopener noreferrer"` ausgeben.
4. `review_only=true` sichtbar als Review-Hinweis markieren, nicht als offizieller Anbieterlink darstellen.
5. `missing` als nicht klickbaren Grund ausgeben.
6. Tabellen fuer Firmeninventar, Backlog, Scanprioritaeten und Importwellen-Kandidaten um Linkspalten erweitern.
7. HTML-Layout mit kurzen Labels, bestehenden Scrollcontainern, Sticky-Headern und ohne externe Ressourcen absichern.
8. `tests\Test-JobAgentCoverage.ps1` um HTML-/Markdown-Linkassertions erweitern; bei Viewport-Aenderung `tests\Test-JobAgentHtmlAudit.ps1` laufen lassen.

## Danach TD-0033 / JA-033

Daily-Run-HTML und Markdown mit offiziellen Stellen- und Anbieterlinks vereinheitlichen:

- `src/JobAgent.Report.psm1`
- `src/JobAgent.DailyRun.psm1`
- `tests/Test-JobAgentReport.ps1`
- `tests/Test-JobAgentDailyRun.ps1`

## Validiert

- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd self-check` -> Exit `0`

## Risiken und Regeln

- Keine Links erfinden.
- Keine Jobboerse als Primaer- oder offizieller Anbieterlink.
- Keine Login-, Captcha-, Tracking- oder Shortener-URLs bevorzugen.
- Keine Bewerbung, kein Formular-Autofill, keine extern wirksame Aktion.
- Supertest gilt nach Nutzeranweisung als erledigt, wenn nicht neu angefragt; fuer JA-031 wurde er trotzdem erfolgreich ausgefuehrt.

CAPSULE:{"ts":"2026-08-24T08:30:00+02:00","agent_id":"codex","workspace_root":"D:\\_Scripte\\JobAgent","project":"JobAgent","active_id":"TD-0032","status":"open","goal":"JA-032 Coverage-HTML mit anklickbaren Anbieter-, Karriere- und ATS-Links ausgeben.","changed":[".ci/pins/immutable.hashes.json",".ci/pins/immutable.snapshot/Roadmap.md","Roadmap.md","Roadmap_archive.md","Roadmap_index.md","docs/company-discovery-operations.md","handoff.latest.json","handoff.latest.md","html/jobagent/company-coverage.html","schemas/jobagent.schema.json","src/JobAgent.Coverage.psm1","tests/Test-JobAgentCoverage.ps1","todo.checkpoint.json","todo.current.md","todo.events.jsonl","todo.history.digest.json","todo.master.index.json","todo.state.json"],"verified":[{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1","exit":0,"status":"pass"},{"cmd":"pwsh -NoProfile -File tests\\Test-JobAgentReport.ps1","exit":0,"status":"pass"},{"cmd":".\\ci.cmd supertest","exit":0,"status":"pass"},{"cmd":".\\ci.cmd stp","exit":0,"status":"pass"},{"cmd":".\\ci.cmd self-check","exit":0,"status":"pass"}],"route_ok":null,"route_violations":[],"git":{"has_repo":true,"branch":"master","detached":false,"upstream":"origin/master","remote":"origin","ahead":0,"behind":0,"worktree":"dirty"},"next":"TD-0032 / JA-032: Coverage-HTML und Markdown aus den JA-031-Linkobjekten rendern.","refs":["todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.json","Roadmap.md","Roadmap_archive.md"],"manual_missing":false,"env_inventory_missing":false,"env_inventory_used":false,"env_inventory_path":null}
