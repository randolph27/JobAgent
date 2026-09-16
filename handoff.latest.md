# Handoff latest

Stand: 2026-09-16T08:03:06.199+02:00

## Zustand

- Active: `TD-0062`
- Status: `in-progress`
- Ziel: QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen #comment: Das blosse Vorhandensein einer Screenshotdatei beweist weder fehlerfreies Layout noch barrierearme Bedienbarkeit.
- Branch: `master`
- HEAD: `3be3dbf79c98`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `handoff.latest.json`
- `handoff.latest.md`
- `tests/Test-JobAgentUiBrowserAudit.ps1`
- `tests/fixtures/jobagent/QA-005-visual-contract.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` -> Exit `0`; lokaler CI-Devserver auf Port 8500, isolierte Browserfixture.

## QA-005.1: umgesetzter Stand

- `tests/fixtures/jobagent/QA-005-visual-contract.json` beschreibt vier feste Messfenster: 390x844, 800x1024, 1366x768 und 1920x1080. Vertraglich gelten DeviceScaleFactor 1, hoechstens ein CSS-px Root-Overflow und mindestens 44 CSS-px fuer sichtbare Controls.
- `tests/Test-JobAgentUiBrowserAudit.ps1` misst die sechs Pflichtzustaende `initial_jobs`, `complex_filter`, `empty_results`, `company_without_open_jobs`, `last_jobs_page` und `long_content` an jedem festen Fenster.
- Die Browsermessung prueft Rootbreite, sichtbare Control-Boundingboxes, Mindestgroesse, Austritt aus dem Viewport, Ueberlappungen zwischen verschiedenen Controls und abgeschnittene Textinhalte. Die Messwerte werden als `geometry` in `logs/jobagent/QA-004/<run-id>/browser-cases.json` abgelegt.
- Vor der Messung werden CSS-Animationen und -Transitions deaktiviert; der Audit wartet auf `document.fonts.ready` und erzwingt Locale `de-DE` sowie Zeitzone `UTC`.

## Verbleibende Arbeit

1. QA-005.1 vollstaendig abschliessen: den im Vertragsfixture bereits definierten 200-%-Desktopzoom messbar ausfuehren und die Ergebniswerte in die Browser-Evidence aufnehmen. Danach nur `Test-JobAgentUiBrowserAudit.ps1` erneut ausfuehren.
2. QA-005.2: Tastaturreise, Fokus, Rollen/zugreifbare Namen, Labelzuordnung und berechneten Kontrast in derselben isolierten Browserfixture testen.
3. QA-005.3: Screenshots je Pflichtzustand unter `logs/jobagent/QA-005/screens/` erzeugen, manuell sichten, Hashmanifest/Nachweis anlegen und vier negative Rendererfixtures (Clipping, Overlap, zu kleines Control, unsichtbarer Fokus) als erwartete Fehler pruefen.
4. QA-005 erst nach allen drei Unterpunkten abschliessen und aus `Roadmap.md` rotieren. QA-006 bleibt bis dahin blockiert durch seine Roadmap-Abhaengigkeit. `TD-0056` ist davon unabhaengig offen.

## Testregel

- Kein Supertest fuer diesen Arbeitsschnitt angefordert; deshalb nicht als ausstehender Validierungsschritt behandeln. Bei einem vollstaendig abgeschlossenen Roadmap-Punkt bleibt dessen vertraglich definierter Supertest separat zu bewerten.

## Naechster Anker

QA-005.1: 200-%-Desktopzoom als Geometriemessung ausfuehren und im Browser-Evidence erfassen.
