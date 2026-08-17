# Handoff latest

Stand: 2026-08-17T17:53:56.738+02:00

## Zustand

- Active: `TD-0017`
- Status: `in-progress`
- Ziel: `JA-021 Firmeninventar autonom, dedupliziert und quellenorientiert erweitern`
- Branch: `master`
- HEAD: `0c47fb4a6852`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`

## Abgeschlossener Arbeitsschritt

- `src/JobAgent.CompanyInventory.psm1` erweitert den Discovery-Vertrag fuer Firmen um `verification_url`, `discovery_origin`, `target_area`, `industry_hint` und `evidence_note`.
- Das Seed-/Merge-Verhalten ist jetzt strenger und verlustfrei: staerkere Verifikationsstufe bleibt erhalten, `scan_priority` wird maximiert, der fruehere `next_scan_at` bleibt bestehen, Standorte/Aliase/ATS-Bindings werden zusammengefuehrt.
- `src/JobAgent.Coverage.psm1` bewertet Firmen jetzt zusaetzlich mit Inventar-Zustaenden wie `MANUAL_REVIEW_REQUIRED`, `VERIFIED_WEBSITE_ONLY`, `RETRY_REQUIRED`, `STALE_SCAN`; daraus werden Backlog-Typen und Scanprioritaeten abgeleitet.
- `schemas/jobagent.schema.json` und alle betroffenen Fixtures/Tests wurden auf das erweiterte `discovery_source`-Schema angehoben.
- `tools/Seed-JobAgentCompanies.ps1` wurde erfolgreich gegen den echten Store ausgefuehrt; `data/jobagent/store.json` ist auf das neue Discovery-Schema normalisiert, Log unter `logs/jobagent/company-seed-20260817-155258.json`.
- `.\ci.cmd stp` wurde ausgefuehrt; `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`, `handoff.latest.json` und `handoff.latest.md` sind synchronisiert.

## Roadmap- und Todo-Status

- `JA-021` ist nicht abgeschlossen und bleibt in `Roadmap.md` aktiv.
- `JA-022` bleibt nachgelagert offen; keine Rotation aus `Roadmap.md`.
- `todo.current.md` und `todo.state.json` bleiben korrekt auf `TD-0017` / `JA-021`.
- Regel des Nutzers: Wenn `supertest` nicht erneut angefragt wurde, gilt der letzte gruene Lauf als erledigt. Diese Annahme bleibt aktiv.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File tools\Seed-JobAgentCompanies.ps1` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> letzter gruener Digest gilt gemaess Nutzerregel als erledigt

## Naechste Arbeit

1. `JA-021` fachlich abschliessen: echte autonome Firmen-Erweiterung fehlt noch. Bisher existiert nur der Vertrag, die Merge-/Priorisierungslogik und die Schemahaertung.
2. Neue Firmen-Discovery implementieren: neue erlaubte Discovery-Quellen oder Seed-Importer anlegen, damit systematisch weitere Arbeitgeber fuer Muenchen/Freising aufgenommen werden koennen.
3. Discovery sauber verifizieren: Sekundaerquellen duerfen nur `DISCOVERY_HINT` erzeugen; eine Firma darf erst als belastbar gelten, wenn offizielle Website und idealerweise Karriere-URL belegt sind.
4. Coverage-/Daily-Run-Nutzung fertigstellen: pruefen, ob die neuen Inventar-Zustaende und Priorisierungen in weiteren operativen Pfaden genutzt oder sichtbar gemacht werden muessen.
5. Erst nach Abschluss von `JA-021`: `JA-022` beginnen, also Devserver-Portvertrag `8500`/`8300` bereinigen, lokalen HTML-Audit bauen und Reportpfade/Betriebsstatus absichern.

## Risiken und No-Gos

- Keine neue Firma ohne belastbare Quelle.
- Discovery aus Jobboersen oder anderen Sekundaerquellen nie als Verifikation behandeln.
- Rechtlich getrennte Arbeitgeber nicht ueber Alias-, Konzern- oder Domain-Aehnlichkeit falsch zusammenfuehren.
- Keine Vollstaendigkeitsbehauptung; der aktuelle Stand ist eine gehaertete Grundlage, aber noch keine autonome Firmenabdeckung.
