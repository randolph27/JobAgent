# Handoff: QA-005 Browseraudit – Syntaxkorrektur und Fortsetzung

Stand: 2026-09-16T11:00:00+02:00

## Aktiver Arbeitspunkt

- Todo: `TD-0062`, Status `in-progress`.
- Roadmap: `QA-005 Layout, Lesbarkeit und Tastaturbedienung messbar abnehmen`.
- `QA-005.1` ist als erledigt markiert. `QA-005.2` und `QA-005.3` sind offen.
- `QA-006` (`TD-0063`) bleibt bis zum vollständigen QA-005-Abschluss gesperrt.
- `TD-0056` bleibt unverändert offen; Sonar ist weiterhin `not-supported` und gehört nicht in diesen Arbeitsschnitt.

## Korrigierte Ursache

In `tests/Test-JobAgentUiBrowserAudit.ps1` enthielt die XSS-Regressionsprüfung für
`HTML-Script-Fragment bleibt Textinhalt` einen ungültig gequoteten JavaScript-Selector:

```javascript
document.querySelectorAll(''[id=jobagent-job-results] img'')
```

Die Playwright-Auswertung brach deshalb mit `SyntaxError: Unexpected token '*'` ab.
Der Selector nutzt nun gültige doppelte JavaScript-Anführungszeichen:

```javascript
document.querySelectorAll("[id=jobagent-job-results] img")
```

Die Korrektur beschränkt sich auf die Testauswertung; Produktcode und Fixture-Daten
wurden nicht verändert.

## Durchgeführte Verifikation

- PowerShell-Parser für `tests/Test-JobAgentUiBrowserAudit.ps1`: erfolgreich (`syntax-ok`).
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`: Exit `0`.
- `git diff --check`: erfolgreich vor dem Staging.
- `.\ci.cmd stp`: erfolgreich; `Test-JobAgentCiContracts.ps1` Exit `0`.

Ein vollständiger Browseraudit konnte in dieser Sitzung nicht belastbar abgeschlossen
werden: direkte Aufrufe liefen ohne zurückgeliefertes Resultat aus, der explizit
gestartete Hintergrundlauf blieb mehrere Minuten ohne stdout/stderr-Flush aktiv und
wurde anschließend über seine bekannte eigene PID beendet. Das ist kein grüner Test
und darf nicht als QA-005.2-Nachweis behandelt werden.

## Nächster konkreter Ablauf

1. Den Devserverzustand ausschließlich über `.\ci.cmd devserver-status` prüfen;
   bei Bedarf `.\ci.cmd devserver-start` verwenden. Port ist `8500`.
2. Genau den betroffenen Test erneut ausführen:

   ```powershell
   pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1
   ```

   Bei einem Fehler nur den gemeldeten Browser-/Rendererfall isolieren. Kein
   `supertest` für die Fehlerlokalisierung.
3. Bei grünem Audit QA-005.2 vollständig gegen die Roadmap abgleichen: Filter-Tastreise,
   Tabwechsel, Reset- und Paginationfokus, semantische Rollen/Namen, Live-Status sowie
   berechnete Kontrastwerte. Erst dann Roadmap und Todo synchronisieren.
4. Anschließend QA-005.3 implementieren: isolierte Negativrendererfälle für Clipping,
   Control-Overlap, unter 44 CSS-px große Controls und unsichtbaren Fokus. Jede Probe
   muss gezielt fehlschlagen. Screenshots, Hashmanifest und dokumentierte Sichtung für
   Daily- und Coverage-Bericht unter den Roadmap-Pfaden erzeugen. Referenzbilder erst
   nach bestandenen Assertions versionieren.
5. QA-005 erst rotieren, wenn alle drei Unterpunkte, die drei festgelegten Funktionstests
   und die Evidence vollständig vorliegen. Gemäß Nutzeranweisung ist kein zusätzlicher
   Supertest erforderlich.

## Relevante Dateien

- `tests/Test-JobAgentUiBrowserAudit.ps1` – Browser-, Geometrie-, Fokus- und
  XSS-Regressionstest; korrigierte Stelle im Script-Fragment-Fall.
- `tests/fixtures/jobagent/QA-005-visual-contract.json` – vier Pflichtviewports,
  44-CSS-px-Controlminimum, Root-Overflowgrenze und 200-%-Zoom.
- `src/JobAgent.Report.psm1` – zuvor angepasster Render-/Paginationfokus; vor
  Änderungen erst mit dem Browseraudit reproduzieren.
- `Roadmap.md`, `todo.current.md`, `todo.state.json` – weiterhin konsistent auf
  `TD-0062` / QA-005 in Arbeit.

## Git-Übergabe

Der Commit dieser Übergabe enthält ausschließlich die Testsyntaxkorrektur, den
Todo/STP-Metadatenstand und dieses Handoff. Keine Roadmap-Rotation wurde vorgenommen,
weil QA-005 objektiv noch nicht vollständig belegt ist.
