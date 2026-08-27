# Handoff latest

Stand: 2026-08-27T12:33:02.438+02:00

## Neuer-Chat-Start

- Projektpfad: `D:\_Scripte\JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Offener Roadmap-Punkt: `JA-027 Jede Arbeitgeberfirma auf offizielle Jobs-/Karriere-Website pruefen und nur verifizierte Firmen produktiv hinzufuegen`
- Offenes Todo: `TD-0041`
- Roadmap-Rotation: nicht ausgefuehrt, weil JA-027 fachlich noch offen ist.
- SonarQube: zuletzt erreichbar auf `http://localhost:9000/api/system/status` mit `UP`.
- Devserver: zuletzt erreichbar ueber `http://localhost:8500/`.
- Supertest: gemaess Nutzeranweisung fuer diese Uebergabe als erledigt gewertet, nicht neu ausgefuehrt.

## Abgeschlossener Arbeitsschritt

- `src/JobAgent.SourceVerification.psm1` erweitert: `Resolve-JobAgentCandidateOfficialWebsiteDiscovery` kann nun genau eine namenspassende interne Verzeichnisdetailseite laden und dort genau einen externen Firmenwebsite-Link verifizieren.
- Neue interne Logik: `Get-JobAgentCandidateOfficialWebsiteDiscoveryLinksByScope` trennt externe Firmenwebsite-Links von internen Detailseitenlinks.
- Neue Root-Normalisierung: offizielle Website-URLs werden als Domain-Root gespeichert, konkrete Belegpfade bleiben in `verification_url` und `verified_by_url` erhalten.
- Fail-closed-Verhalten bleibt bestehen: Jobboersen/Aggregatoren, fehlende absolute Source-URLs, Namenskonflikte und mehrere Treffer werden nicht automatisch produktiv importiert.
- `tests/Test-JobAgentCompanyCandidateVerification.ps1` erweitert um Detailseiten-Discovery inklusive Tool-Persistenztest.
- Route-Check-Blocker in `Roadmap_archive.md` bereinigt: vorhandenes ESC-Steuerzeichen in `expected_sources_total` ersetzt.

## Produktiver Datenstand

- Produktive Firmen: `42`
- Dublettengruppen: `0`
- `target_inventory_candidates_total`: `1829`
- `target_inventory_gap_to_1000`: `0`
- `target_inventory_gate_status`: `failed`, weil JA-027 weiter offene Review-/Verifikationsarbeit enthaelt.

## Neu produktiv/verifiziert

- `company:behandlungszentrum_fuer_multiple_sklerose_kranke`
  - Name: `Behandlungszentrum fuer Multiple Sklerose Kranke`
  - Status: `COMPANY_DOMAIN_VERIFIED`
  - Website: `https://ms-klinik.de/`
  - Karriere-URL: keine offiziell belegte Karriere-URL gefunden
  - Beleg: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`
- `company:digital_m_gmbh`
  - Name: `digital@M GmbH`
  - Status: `CAREER_URL_VERIFIED`
  - Website: `https://digital-at-m.de/`
  - Karriere-URL: `https://digital-at-m.de/karriere`
  - Beleg: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`
- `company:flughafen_muenchen_gmbh`
  - Name: `Flughafen Muenchen GmbH`
  - Status: `CAREER_URL_VERIFIED`
  - Website: `https://munich-airport.de/`
  - Karriere-URL: `https://munich-airport.de/karriere-7833198`
  - Beleg: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`
- `company:gasteig_muenchen_gmbh`
  - Name: `Gasteig Muenchen GmbH`
  - Status: `CAREER_URL_VERIFIED`
  - Website: `https://gasteig.de/`
  - Karriere-URL: `https://gasteig.de/karriere`
  - Beleg: `https://stadt.muenchen.de/infos/unternehmensbeteiligungen.html`

## Wichtige Artefakte

- `logs/jobagent/company-candidate-website-discovery-20260827-102708.json`
- `logs/jobagent/company-candidate-verification-20260827-102732.json`
- `logs/jobagent/company-candidate-verification-20260827-102750.json`
- `logs/jobagent/company-coverage-20260827-102804.json`
- `logs/jobagent/company-coverage-20260827-102804.md`
- `html/jobagent/company-coverage.html`

## Geaenderte Dateien

- `Roadmap_archive.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `data/jobagent/company-discovery.hints.json`
- `data/jobagent/store.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3` -> Exit `0`
- `pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250` -> Exit `0`
- `.\ci.cmd route-check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`
- `.\ci.cmd supertest` -> nicht neu ausgefuehrt; gemaess Nutzeranweisung als erledigt gewertet.

## Naechste Aufgaben

1. Weitere `DISCOVER_OFFICIAL_WEBSITE`-Kandidaten aus zulaessigen Regional-/Institutionenquellen in kleinen Wellen verarbeiten.
2. Detailseiten-Erkennung gezielt fuer Quellen wie `munich-business.eu` und `freising.de` ausbauen, aber nur wenn pro Kandidat eine eindeutige Detailseite belegbar ist.
3. Danach erneut ausfuehren:

```powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -MaxCandidates 25 -TimeoutSeconds 8
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -MaxCandidates 10 -TimeoutSeconds 8 -MaxRetries 3
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -MaxPriorityItems 250
```

4. JA-027 erst rotieren, wenn alle Akzeptanzbedingungen belegt sind:
   - jede produktiv aufgenommene Firma hat offizielle Website-/Karriere-/ATS-Evidence,
   - nicht uebernommene Kandidaten haben Review-/Reject-Grund,
   - Coverage-/Report-Artefakte sind aktuell,
   - Funktionstests sind gruen,
   - Supertest ist ausgefuehrt oder durch Nutzeranweisung als erledigt gewertet.
