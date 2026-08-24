# Handoff latest

Stand: 2026-08-24T11:10:32.084+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: 
- Branch: `master`
- HEAD: `ff584cfabdc2`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `Roadmap.md`
- `Roadmap_archive.md`
- `Roadmap_index.md`
- `data/jobagent/company-candidate-verification.queue.json`
- `handoff.latest.json`
- `handoff.latest.md`
- `html/jobagent/company-coverage.html`
- `html/jobagent/ja-022-viewport-audit.html`
- `output/playwright/ja-022-viewport-1366.png`
- `output/playwright/ja-022-viewport-1920.png`
- `output/playwright/ja-022-viewport-800.png`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentDailyRun.ps1`
- `tests/Test-JobAgentHtmlAudit.ps1`
- `tests/Test-JobAgentReport.ps1`
- `todo.checkpoint.json`
- `todo.current.md`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `todo.state.json`

## Verifikation

- `.\ci.cmd supertest` -> Exit `0`

## Naechster Anker

Aktive Punkte: JA-025 Firmeninventar auf mindestens 1000 verifizierte oder prüfbare Zielgebiet-Kandidaten erweitern #comment: Der lokale Store muss statt weniger Dutzend Firmen eine skalierbare, belegte Kandidatenbasis fuer Muenchen, 20-km-Umkreis und Freising enthalten.

## Uebergabe fuer neuen Chat

### Abgeschlossen

- JA-024 ist fachlich abgeschlossen und nach `Roadmap_archive.md` rotiert.
- Daily-Run-Reports zeigen in HTML und Markdown nun direkt nutzbare Jobtabellen mit `Titel`, `Firma`, `Standort`, `Prioritaet`, `Status`, `Offizielle Stellen-URL`, `Karriere-URL` und `Quelle`.
- Offizielle Stellenlinks und Karriere-URLs werden als sichere Links mit `target="_blank"` und `rel="noopener noreferrer"` gerendert.
- `New-JobAgentReportJobEntry` fuehrt jetzt `career_url` aus dem Firmeninventar ins Report-Viewmodel.
- Report-, Daily-Run-, HTML-Audit- und Viewport-Tests wurden angepasst; der Supertest lief erfolgreich.

### Relevante Aenderungen

- `src/JobAgent.Report.psm1`: Jobtabellen umsortiert, `career_url` ins Viewmodel aufgenommen, Markdown-Firmenlinks fuer neue Unternehmen klickbar gemacht.
- `tests/Test-JobAgentReport.ps1`: Assertions auf neue Spaltenreihenfolge und Linklabels aktualisiert.
- `tests/Test-JobAgentDailyRun.ps1`: Daily-Run-Artefakte pruefen jetzt `Offizielle Stellen-URL` und `Karriere-URL`.
- `tests/Test-JobAgentHtmlAudit.ps1`: HTML-Audit prueft Pflichtspalten und sichere Karriere-/Stellenlinks.
- `html/jobagent/ja-022-viewport-audit.html` und `output/playwright/ja-022-viewport-*.png`: Viewport-Audit-Artefakte wurden neu erzeugt.

### Offene Aufgaben

- JA-025: Firmeninventar auf mindestens 1000 verifizierte oder pruefbare Zielgebiet-Kandidaten erweitern. Start mit Quelleninventar, Importwellen, Dedupe und Coverage-Gates. Funktionstests laut Roadmap: `Test-JobAgentCompanyInventory.ps1`, `Test-JobAgentImportWaves.ps1`, `Test-JobAgentCoverage.ps1`, `Test-JobAgentCompanyDedupeScale.ps1`.
- JA-026: Daily-Run-Scanbreite konfigurierbar machen und im Bericht transparent ausweisen, ob `3` ein Limit oder die Datenbasis ist. Abhaengig von JA-024, fachlich stark von JA-025.
- JA-027: Karriere-/ATS-Link-Ermittlung skalieren und generische Such-/FAQ-/Landingpages nicht als Jobdetail persistieren.
- TD-0042: CI-Route/Drift meldet bestehende Markdown-Fence-Verletzungen in `templates/chess/README.md:1027` und `templates/ubuntu-web/README.md:1033`. Das ist aktuell der verbleibende Route-Check-Befund.

### Betriebsstatus

- SonarQube `http://localhost:9000/api/system/status`: `UP`.
- Devserver `http://localhost:8500/`: laeuft.
- Letzter Supertest: `.\ci.cmd supertest` -> Exit `0`.
