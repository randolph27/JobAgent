# Handoff latest

Stand: 2026-09-17T22:40:00+02:00

## Zustand

- Active: `TD-0075 / JA-047`
- Status: `in-progress`
- Ziel: Stellenfilter, Suche, Sortierung und Hashnavigation vollständig abnehmen.
- Branch: `master`
- HEAD: `3aa730f84a65` (vor dem noch ausstehenden Commit)
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `docs/handoffs/2026-09-17-ja-047-in-progress.md`: korrigierter Befund und Wiederanlauf.
- `handoff.latest.json`, `handoff.latest.md`, `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`: durch `./ci.cmd stp` synchronisiert.
- `tests/Test-JobAgentUiBrowserAudit.ps1`: Facetten prüfen die vollständige Trefferzahl, Seitenzahl und sichtbare Anzahl; eine Karte außerhalb der ersten 50er-Seite wird nicht mehr irrtümlich als fehlender Filtertreffer bewertet. Die `UNKNOWN`-Auswahl wird über den kanonischen Hash gesetzt.

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`
- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -FixtureOnly` -> Exit `0`
- `./ci.cmd stp` -> Exit `0`; Route bleibt `False` ausschließlich wegen gebündelter Sonar-JRE-Lizenzdateien (`TD-0085`), nicht ändern oder löschen.
- Der vollständige `Test-JobAgentUiBrowserAudit.ps1` hat noch keinen belastbaren Exitcode. Abgebrochene lokale Läufe hinterlassen Playwright-/Chrome-Kindprozesse; weder Roadmap noch Todo dürfen daraus einen Abschluss ableiten.

## Naechster Anker

1. Ausschließlich Prozesse mit eindeutigem Bezug zu abgebrochenen QA-004-Playwright-Läufen kontrolliert beenden; keinen fremden Chrome-Prozess anfassen.
2. `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` vollständig bis Exit 0 ausführen.
3. Bei Grün `docs/reviews/JA-047-acceptance.md` und `logs/jobagent/JA-047/filter-matrix.json` erzeugen, JA-047 nach `Roadmap_archive.md` rotieren sowie Todo/Checkpoint/Handoff synchronisieren. Supertest ist laut Nutzerauftrag erledigt und wird nicht ausgeführt.
4. Danach JA-048 beginnen. Aktive Reihenfolge: JA-047 → JA-048 → JA-052 → JA-053 → JA-055 → JA-049 → JA-054 → JA-056 → JA-050.
