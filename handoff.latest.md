# Handoff latest

Stand: 2026-09-16T08:57:32.204+02:00

## Zustand

- Active: `TD-0062`
- Status: `in-progress`
- Ziel: QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen #comment: Das blosse Vorhandensein einer Screenshotdatei beweist weder fehlerfreies Layout noch barrierearme Bedienbarkeit.
- Branch: `master`
- HEAD: `5b3e356023d8`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Detaillierter Fortsetzungsstand

- Aktive Arbeit bleibt `TD-0062` / `QA-005`. Der Hauptpunkt ist nicht vollstaendig, daher keine Rotation nach `Roadmap_archive.md`.
- `QA-005.1` ist erledigt und in `Roadmap.md` markiert. Der isolierte Browseraudit deckt die sechs Vertragszustaende in 390x844, 800x1024, 1366x768 und 1920x1080 ab; Root-Overflow, Controlgroesse, Viewport-Austritt, Overlap, Text-Clipping und 200-%-Zoom auf 1366x768 werden gemessen.
- Letzter erfolgreicher Browsernachweis: `logs/jobagent/QA-004/qa004-cb9aadbc34f54e579c82094aa7628167/browser-cases.json` mit `status: ok`, 25 Geometrieeintraegen, einem `initial_jobs_200_percent_zoom`-Eintrag und vier Screenshots. Die Evidence liegt aus historischem Testaufbau noch unter `QA-004`; QA-005.3 muss die geforderten QA-005-Pfade verwenden.
- Die Browser-Voraussetzungen sind hergestellt: `tests/Test-JobAgentUiBrowserAudit.ps1` setzt einen lokalen npm-Cache unter `.ci/cache/npm` (ignoriert), erzeugt eine isolierte Playwright-CLI-Konfiguration mit `de-DE` und `UTC` und erwartet den Browseraudit ausserhalb der Sandbox, damit der vorhandene lokale Playwright-Daemon und Browser genutzt werden kann.
- Gruene Tests: `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`. Der Devserver auf Port 8500 war erreichbar. Kein Supertest wurde ausgefuehrt; gemaess Nutzerregel gilt er als erledigt, ohne offene Funktionstests oder Akzeptanznachweise zu ersetzen.

## Naechster Arbeitsschnitt

1. QA-005.2 umsetzen: komplette Tastaturreise fuer Filter, Tabs und Pagination; sichtbarer Fokus, korrekte Fokusreihenfolge nach Reset/Seitenwechsel, keine Tastaturfalle; Rollen, zugreifbare Namen, Labelzuordnung, `aria-selected`, `aria-controls` und Trefferstatus pruefen; Kontrast berechnen.
2. Nur den fokussierten Browseraudit zur Fehlerlokalisierung starten. Falls eine neue Browserumgebung den Daemon nicht erreicht, den Test ausserhalb der Sandbox und mit vorhandenem `.ci/cache/npm` ausfuehren; keine Downloads innerhalb des Testlaufs.
3. QA-005.3 danach abschliessen: Screenshots pro Pflichtzustand nach `logs/jobagent/QA-005/screens/`, Hashmanifest, dokumentierte Sichtung und vier negative Rendererfixtures (Clipping, Overlap, zu kleines Control, unsichtbarer Fokus). Erst nach allen QA-005-Unterpunkten, den drei Roadmap-Funktionstests und vollstaendiger Evidence den Hauptpunkt rotieren; erst dann QA-006 beginnen.

## Offene Punkte

- `TD-0063` / QA-006 ist durch QA-005 abhaengig und bleibt offen.
- `TD-0056` (CI-Drift) bleibt unabhaengig offen; keine Pins, Immutables oder Runtime-Dateien zur kosmetischen Gruenfaerbung aendern.
