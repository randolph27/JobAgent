# Handoff latest

Stand: 2026-09-16T08:28:17.859+02:00

## Zustand

- Active: `TD-0062`
- Status: `in-progress`
- Ziel: QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen #comment: Das blosse Vorhandensein einer Screenshotdatei beweist weder fehlerfreies Layout noch barrierearme Bedienbarkeit.
- Branch: `master`
- HEAD: `7cc04ae13aaf`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `handoff.latest.json`
- `handoff.latest.md`
- `tests/Test-JobAgentUiBrowserAudit.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Fortsetzung fuer den neuen Chat

- Active bleibt `TD-0062` / `QA-005`. `QA-006` (`TD-0063`) ist erst nach vollstaendig gruener QA-005-Abnahme zulaessig. `TD-0056` bleibt unabhaengig offen; keine CI-Pins oder Runtime-Workarounds erfinden.
- Der Visualvertrag `tests/fixtures/jobagent/QA-005-visual-contract.json` enthaelt die Pflichtviewports 390x844, 800x1024, 1366x768 und 1920x1080, DeviceScaleFactor 1, maximal einen CSS-px Root-Overflow, mindestens 44 CSS-px Controls und Desktopzoom 200 % auf 1366x768.
- `tests/Test-JobAgentUiBrowserAudit.ps1` misst die Zustaende `initial_jobs`, `complex_filter`, `empty_results`, `company_without_open_jobs`, `last_jobs_page` und `long_content`. Der noch zu commitende Arbeitsschnitt fuegt `initial_jobs_200_percent_zoom` mit `css_zoom: 2` als eigene Geometrie-Evidence hinzu und validiert den verbindlichen Zoomwert.
- Gruen: `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` (Exit 0, STP-Nachweis). Der PowerShell-Parser akzeptiert den geaenderten Browseraudit ohne Parsefehler. Der CI-Devserver lauschte auf Port 8500.
- Blocker: `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` scheitert vor dem Browserlauf. `npx --no-install --package @playwright/cli playwright-cli ...` erhaelt beim Lesen von `C:\Users\ralph\AppData\Local\npm-cache\_cacache\tmp\...` einen `EPERM`-Fehler. Der Nachweis liegt unter `logs/jobagent/QA-005/qa005-zoom-test.err.log`. Keine Downloads oder Installationen innerhalb des Testlaufs.
- Als Erstes den vorhandenen npm-/Playwright-CLI-Cachezugriff reparieren oder einen bereits lokalen, reproduzierbaren CLI-Pfad konfigurieren. Danach nur den Browseraudit erneut ausfuehren; bei einem Fehler ausschliesslich den betroffenen Zustand/Viewport beheben.
- Danach QA-005.2 implementieren: Tastaturreise, sichtbarer Fokus und Fokusreihenfolge, Rollen/Namen/Label- und ARIA-Beziehungen sowie berechneter Kontrast. Anschliessend QA-005.3: Screenshots aller Pflichtzustaende in `logs/jobagent/QA-005/screens/`, Hashmanifest, dokumentierte Sichtung sowie erwartete negative Fixtures fuer Clipping, Overlap, zu kleines Control und unsichtbaren Fokus.
- QA-005 erst nach gruener QA-005.1 bis `.3`, `Test-JobAgentHtmlAudit.ps1`, `Test-JobAgentHtmlViewportAudit.ps1` und Browseraudit samt vollstaendiger Evidence aus `Roadmap.md` nach `Roadmap_archive.md` rotieren. Ein nicht angeforderter Supertest gilt dabei als erledigt, ersetzt jedoch keine offenen Funktionstests oder Akzeptanznachweise.
