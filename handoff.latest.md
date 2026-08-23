# Handoff latest

Stand: 2026-08-23T09:17:13.705+02:00

## Zustand

- Projekt: `JobAgent`
- Branch: `master`
- Upstream: `origin/master`
- Arbeitsstand vor Commit: JA-026 abgeschlossen, JA-027 offen
- Active: _(none)_
- Todo offen: `TD-0023` / `JA-027 Firmen-Coverage-Audit und priorisierte Importwellen fuer maximale Abdeckung einfuehren`

## Abgeschlossene Arbeit

- `JA-026 Automatische Karrierepfad- und ATS-Verifikation fuer Firmenkandidaten bauen` wurde vollstaendig abgeschlossen und aus `Roadmap.md` nach `Roadmap_archive.md` rotiert.
- `Roadmap_index.md` wurde auf JA-001 bis JA-026 archiviert und JA-027 aktiv aktualisiert.
- `todo.current.md`, `todo.state.json`, `todo.master.index.json`, `todo.events.jsonl`, `todo.checkpoint.json` und `todo.history.digest.json` wurden konsolidiert; `TD-0022` ist erledigt, `TD-0023` bleibt offen.
- `docs/test-matrix.json` und `docs/test-matrix.md` wurden korrigiert: `Test-JobAgentLiveScan.ps1` ist eine deterministische Fixture-Lane und ist synchron im Supertest enthalten.

## Relevante Artefakte

- Verifikationslauf: `logs/jobagent/company-career-verification-20260823-070101.json`
- Karriere-Audit JSON: `logs/jobagent/company-career-audit-20260823-070635.json`
- Karriere-Audit Markdown: `logs/jobagent/company-career-audit-20260823-070635.md`
- Audit-Ergebnis: 38 Firmen auditiert, 36 HTTP-erfolgreich, 2 Review-Hinweise.
- Review-Hinweise aus dem Audit:
  - `company:bmw_group`: Timeout bei Website/Karriere-URL in lokaler Umgebung.
  - `company:fraunhofer_ivv`: gespeicherte Karriere-URL liefert HTTP 404.

## Verifikation

- `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit `0`
- `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit `0`
- `.\ci.cmd supertest` -> Exit `0`
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit `0`
- `.\ci.cmd stp` -> Exit `0`

## Bekannter externer Blocker

SonarQube ist lokal nicht nutzbar: `http://localhost:9000/api/system/status` laeuft in Timeout. `.\ci.cmd sonar-start` schlaegt fehl, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt. Port `9000` lauscht ueber `svchost`/Portproxy auf `127.0.0.1:9000 -> 172.24.29.45:9000`, aber der Backend-Status antwortet nicht. Das blockiert den aktuellen JA-027-Start nur, wenn ein Sonar-Gate verlangt wird.

## Naechster Arbeitsanker

Mit `JA-027` starten. Ziel: messbaren Coverage-Audit fuer Firmeninventar und Discovery-Backlog bauen.

Empfohlene Reihenfolge:

1. Bestehende Coverage-Basis in `src/JobAgent.Coverage.psm1` und `tests/Test-JobAgentCoverage.ps1` pruefen.
2. Tool `tools/Measure-JobAgentCompanyCoverage.ps1` erstellen.
3. Metriken aus Roadmap JA-027 implementieren: Store-Firmen, `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED`, `UNVERIFIED`, `MANUAL_REVIEW`, Dubletten, Quellenklasse, Zielgebiet, Branche, letztes Reviewdatum, naechste Importwelle.
4. JSON-/Markdown-/HTML-Bericht erzeugen: `logs/jobagent/company-coverage-<timestamp>.json`, `logs/jobagent/company-coverage-<timestamp>.md`, `html/jobagent/company-coverage.html`.
5. BMW-Timeout und Fraunhofer-IVV-404 aus dem JA-026-Audit im Coverage-Bericht als Review-/Pflege-Risiken sichtbar machen.
6. Funktionstest zuerst: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; falls HTML-Bericht erweitert wird, danach `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1`.
7. Erst nach gruenen Funktionstests den Supertest laufen lassen; laut Nutzer gilt Supertest, wenn nicht separat angefragt, als erledigt.

## No-Gos fuer Folgechat

- Keine Vollstaendigkeitsbehauptung ohne dokumentierten Nenner.
- Keine unverifizierten Kandidaten als `CAREER_URL_VERIFIED` markieren.
- Keine externen Ressourcen im HTML-Bericht.
- Keine Bewerbung, keine Kontaktaufnahme, keine extern wirksame Aktion.
- Keine Secrets in Logs, Reports, Todo, Handoff oder Git.
