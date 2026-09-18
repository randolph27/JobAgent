# Handoff latest

Stand: 2026-09-18T20:49:29.3665356+02:00

## Zustand

- Active: `TD-0084`
- Status: `in-progress`
- Ziel: M3 - Publikation und Gesamtabnahme: JA-056 Gespeicherte Suchauftraege und neue Treffer seit letzter Sichtung bereitstellen #comment: Wiederholbare Suchprofile und ein generationengebundener Treffervergleich sollen Sucharbeit sparen, ohne alte Jobs nach jedem Scrape erneut als neu auszugeben.
- Branch: `master`
- Basis-Commit: `45673ce` (`feat(jobagent): add saved search state contract`)
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: nach dem Basis-Commit und Push bereinigt
- Route: `False`

## Übergabe JA-056

- `Roadmap.md`
- `handoff.latest.detail.md`
- `handoff.latest.md`
- `handoff.latest.json`
- `html/jobagent/assets/jobboard-state.js`
- `schemas/jobagent.user-state.schema.json`
- `tests/Test-JobAgentUserState.ps1`
- `docs/contracts/JA-056-saved-searches.md`
- `tests/fixtures/jobagent/saved-searches.json`
- `tests/fixtures/jobagent/user-state/valid-v2-saved-search.json`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`

Der erste JA-056-Schritt ist erledigt und in der Roadmap markiert: Der lokale v2-Zustand enthält jetzt optionale `saved_searches` mit maximal 50 Aufträgen, stabiler ID, normalisiertem Namen, kanonischen Filtern, expliziter Reportgeneration sowie bestätigten Job- und Change-Event-IDs. Die State-API speichert, aktualisiert/rebaset, löscht und markiert Sichtungen atomar. Der Vergleich erhält ausschliesslich kanonisch gefilterte IDs und trennt „Neu in dieser Suche“, fachliche Änderungen und nur durch persönliche Auswahl sichtbar gewordene Treffer.

## Verifikation

- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` -> Exit `0`
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `git diff --check` -> Exit `0`
- `./ci.cmd stp` -> Exit `0`
- `git push origin master` -> `f5b8480..45673ce`

## Naechster Anker

JA-056 fortsetzen, nicht JA-050: (1) `scan_run_id` als stabile Generationskennung in die Clientdaten aufnehmen, (2) Suchauftrags-UI an den bestehenden kanonischen Filterresolver anbinden, (3) Aufrufen setzt Ansicht Stellen und Seite 1; fehlende gespeicherte Facetten sichtbar erhalten, (4) Speichern/Bearbeiten/Duplizieren/Löschen/„Als gesehen markieren“ als getrennte lokale, atomare Aktionen integrieren, (5) fokussierten SavedSearch- und Browser-Test samt 1366/390-Evidence ergänzen. Erst danach TD-0084 abschliessen und JA-056 rotieren. TD-0085 bleibt ein separater, vorbestehender CI-Driftpunkt; `route_ok=false` stammt aus gebündelten Sonar-JRE-Lizenzdateien und ist nicht Teil von JA-056.
