# Handoff latest

Stand: 2026-08-24T11:45:00+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- Letzter bekannter HEAD vor Commit: `a0b46998d798`
- Upstream: `origin/master`
- Worktree vor Abschluss-Commit: `dirty`
- Route: `ok`
- Aktiver Todo: keiner gesetzt
- Offene Roadmap-Punkte: `JA-025`, `JA-027`
- Roadmap-Rotation: keine Rotation erfolgt, weil kein Roadmap-Punkt fachlich komplett erledigt ist.

## Abgeschlossener Arbeitsschritt

JA-025 wurde um ein fail-closed Zielinventar-Gate erweitert. Das ist ein Teilschritt, kein kompletter Abschluss von JA-025.

Umgesetzt:

- `src/JobAgent.Coverage.psm1`
  - `New-JobAgentCoverageReport` berechnet jetzt `target_inventory_gate`.
  - Neue Gate-Metriken: `target_inventory_candidates_total`, `target_inventory_gap_to_1000`, `scannable_without_official_source`.
  - Gate-Schema: `jobagent/company-target-inventory-gate/v1`.
  - Gate-Status ist nur `passed`, wenn mindestens 1000 Zielgebiet-Kandidaten vorhanden sind, keine Duplicate-Groups existieren und keine scanfaehige Firma ohne offiziellen Quellenbeleg auftaucht.
  - Fail-closed Violations: `INVENTORY_CANDIDATES_BELOW_1000`, `DUPLICATE_GROUPS_PRESENT`, `SCANNABLE_COMPANY_WITHOUT_OFFICIAL_SOURCE`.

- `tools/Measure-JobAgentCompanyCoverage.ps1`
  - Markdown-/HTML-Kernmetriken zeigen jetzt `Zielgebiet-Kandidaten gesamt`, `Luecke bis 1000 Kandidaten` und `Scanfaehig ohne offiziellen Beleg`.
  - JSON-CLI-Ausgabe enthaelt jetzt `target_inventory_candidates_total`, `target_inventory_gap_to_1000` und `target_inventory_gate_status`.

- `tests/Test-JobAgentCoverage.ps1`
  - Testet das neue Zielinventar-Gate.
  - Testet Konsistenz zwischen Firmenbestand, Kandidatenclustern und 1000er-Luecke.
  - Testet fail-closed Verhalten fuer zu kleine Kandidatenbasis und scanfaehige Firmen ohne offiziellen Beleg.
  - Testet Sichtbarkeit der neuen Metriken in Markdown und HTML.

- Aktualisierte Artefakte:
  - `html/jobagent/company-coverage.html`
  - `data/jobagent/company-candidate-verification.queue.json`

## Verifikation

Ausgefuehrt und erfolgreich:

- `pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd drift-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

Hinweis: `.\ci.cmd supertest` wurde in diesem Arbeitsschritt nicht neu ausgefuehrt. Laut aktueller Nutzeranweisung gilt ein nicht angefragter Supertest als erledigt. Letzter im Handoff vorhandener Supertest-Nachweis war Exit `0`.

## Offene Aufgaben fuer den naechsten Chat

1. Mit `JA-025 / TD-0039` weitermachen.
   - Ziel bleibt: mindestens 1000 eindeutige, belegte Firmen- oder Arbeitgeberkandidaten fuer Muenchen, 20-km-Umkreis und Freising.
   - Aktueller produktiver Store enthaelt weiterhin nur 38 Firmen.
   - Das neue Gate macht die Luecke sichtbar, erzeugt aber noch keine neuen 1000 Kandidaten.

2. Naechster fachlicher Schritt fuer JA-025:
   - Erlaubte Register-/Regional-/Jobboard-Snapshotquellen massentauglich erweitern.
   - Keine Live-/Paywall-/Login-/Captcha-Quellen nutzen.
   - Jobboersen nur als Discovery-Hints verwenden, nie als Primaerbeleg.
   - Unverifizierte Kandidaten in `data/jobagent/company-discovery.hints.json` und Verifikationsqueue halten.
   - Produktive Store-Upserts nur fuer `COMPANY_DOMAIN_VERIFIED`, `CAREER_URL_VERIFIED` oder `OFFICIAL_ATS_VERIFIED`.

3. Empfohlene konkrete Arbeit:
   - Fixture-/Snapshot-Lane fuer grosse Kandidatenmengen erweitern.
   - Import-/Dedupe-Coverage so ausbauen, dass `target_inventory_candidates_total >= 1000` erreichbar und belegbar wird.
   - Coverage-Gate weiter nutzen: keine Dubletten, keine scanfaehigen Firmen ohne offizielle Karriere-/ATS-Evidenz.

4. Danach `JA-027 / TD-0041` angehen.
   - Karriere-/ATS-Link-Ermittlung fuer die gewachsene Kandidatenbasis skalieren.
   - Generische Such-, FAQ- und Landingpages duerfen nicht als Jobdetail persistiert werden.

## Wichtige Dateien

- `Roadmap.md`
- `todo.current.md`
- `todo.state.json`
- `src/JobAgent.Coverage.psm1`
- `src/JobAgent.CompanyInventory.psm1`
- `src/JobAgent.SourceVerification.psm1`
- `tools/Measure-JobAgentCompanyCoverage.ps1`
- `tools/Import-JobAgentCompanyDiscovery.ps1`
- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCoverage.ps1`
- `tests/Test-JobAgentCompanyDedupeScale.ps1`
- `data/jobagent/store.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/company-candidate-verification.queue.json`
- `html/jobagent/company-coverage.html`

## No-Gos

- Keine erfundenen Firmen, URLs, Job-IDs, Geodaten oder Verifikationsaussagen.
- Keine Aggregatorlinks als Primaerbeleg.
- Keine produktiven Store-Upserts aus unverifizierten Discovery-Hints.
- Keine Roadmap-Rotation fuer JA-025 oder JA-027 ohne fachlich belegten Abschluss.
