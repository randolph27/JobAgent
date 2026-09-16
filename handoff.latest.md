# Handoff latest

Stand: 2026-09-16T09:12:47.351+02:00

## Zustand

- Active: `TD-0062`
- Status: `in-progress`
- Ziel: QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen #comment: Das blosse Vorhandensein einer Screenshotdatei beweist weder fehlerfreies Layout noch barrierearme Bedienbarkeit.
- Branch: `master`
- HEAD: `82bae8a15638`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentUiBrowserAudit.ps1`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Detaillierter Fortsetzungsstand

- `TD-0062` / `QA-005` bleibt aktiv; nur QA-005.1 ist abgeschlossen. Keine Roadmap-Rotation, da QA-005.2 und QA-005.3 offen sind.
- `src/JobAgent.Report.psm1` erweitert die Tab-Controls um `ArrowLeft`, `ArrowRight`, `Home` und `End`. Der Zieltab wird fokussiert und aktiviert. Nach einem Seitenwechsel fokussiert der Renderer die deaktivierte aktuelle Seitentaste.
- `tests/Test-JobAgentUiBrowserAudit.ps1` misst jetzt berechneten Text-/Control-Kontrast, sichtbare Fokusumrandungen, Label-/Control-Zuordnung, Tab-/Panel-Beziehung und Live-Status. Die Tastaturreise prueft den Fokus von Freitext durch alle Filter bis Reset sowie die Tabreise mit Pfeiltasten.
- Gruen: `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`, jeweils Exit 0. PowerShell-Parser fuer den Browseraudit und `git diff --check` waren ebenfalls fehlerfrei.
- Nicht gruen und nicht als Erfolg zu werten: der fokussierte Browseraudit. Die ersten drei Laeufe endeten nacheinander an einem ungueltigen leeren CSS-Selector, einer zu engen Button-Label-Assertion und der Kontrastberechnung. Diese drei Ursachen sind im aktuellen Stand korrigiert. Der vierte Lauf erreichte die Fokusinitialisierung, scheiterte dort an der Playwright-CLI-Argumentquotierung (`ReferenceError: jobagent is not defined`). Die IDs werden jetzt per `String.fromCharCode` an die CLI uebergeben; dieser letzte Stand wurde noch nicht vollstaendig wiederholt.
- Die Browserausfuehrung muss ausserhalb der Sandbox mit dem vorhandenen lokalen Cache `.ci/cache/npm` und dem laufenden CI-Devserver auf Port 8500 erfolgen. Keine Downloads installieren. Der Test schreibt nur isolierte Artefakte unter `logs/jobagent/QA-004/<run-id>/`.

## Naechster konkreter Schnitt

1. `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` ausserhalb der Sandbox erneut ausfuehren und den ersten konkreten Fehler isoliert beheben.
2. Bei gruenem Lauf QA-005.2 vervollstaendigen: Fokus nach Reset und Pagination explizit nachweisen; Evidence in den Browser-Case-JSON aufnehmen.
3. QA-005.3 ausfuehren: Screenshots in `logs/jobagent/QA-005/screens/`, Hashmanifest und Sichtungsbefund erstellen; vier negative Rendererfixtures fuer Clipping, Overlap, zu kleines Control und unsichtbaren Fokus nachweisen.
4. Erst nach allen drei QA-005-Funktionstests und vollstaendiger Evidence QA-005 abschliessen und nach `Roadmap_archive.md` rotieren. Supertest gilt gemaess Nutzerregel als erledigt, weil er nicht angefragt wurde.

## Offene Punkte

- `TD-0063` / QA-006 bleibt von QA-005 abhaengig.
- `TD-0056` bleibt unabhaengig offen. Keine Pins, Immutables oder Runtime-Dateien zur kosmetischen Behebung aendern.
