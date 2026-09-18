# Fortsetzung: JA-055 und anschliessende M3-Punkte

Stand: 2026-09-18, Branch `master`. Der aktive Todo-Eintrag bleibt `TD-0082` / `JA-055`; Roadmap-Reihenfolge: `JA-055 -> JA-049 -> JA-054 -> JA-056 -> JA-050`.

## Erledigter Umfang von JA-055

- Browserlokaler State v2 besitzt `hidden_jobs` und `hidden_companies`. Einträge bleiben über stabile IDs, Grund, Freitext (maximal 500 Unicode-Codepoints) und UTC-Änderungszeit erhalten.
- Der Resolver behandelt Jobausblendung vor Arbeitgeberausblendung. Eine einzelne Wiederherstellung hebt eine fortbestehende Arbeitgeberausblendung nicht auf.
- Sichtbarkeitsmodi: `visible`, `all`, `hidden`. Lokale Favoriten und Bewerbungen bleiben in der Standardansicht sichtbar; Doppelmarkierungen zählen im Ausschlusszähler nur einmal.
- Verwaltung, Wiederherstellung, Grund/Text, Reset und mobile Darstellung sind umgesetzt. Alle Daten bleiben im Browser-LocalStorage; keine privaten Gründe in URL oder Reportdaten.

## Belege und erfolgreiche Tests

- [Akzeptanznotiz](../reviews/JA-055-acceptance.md)
- [Sichtbarkeitsfälle](../../logs/jobagent/JA-055/visibility-cases.json) (ignoriertes Laufzeitartefakt)
- [Mobile Verwaltungsansicht](../../doc/roadmap-screenshots/JA-055-hidden-management-390.png), SHA-256 `36ad4ee1826776f78871ae399f8b82fbd5c74dda1be1d934a043f0b274de266d`

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly
```

Der gezielte Browseraudit prüft Grund/Text, Rückgängig, Arbeitgebervorrang, einzelne Wiederherstellung, Reset, exakt `262` sichtbare und `2` ausgeschlossene Stellen, keine fachlichen Bediennetzwerkzugriffe sowie 390×844, 800×1024, 1366×768 und 1920×1080 ohne horizontalen Overflow, Überlappung, zu kleine Controls oder abgeschnittenen Text.

## Noch offen vor Roadmap-Rotation

`pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` wurde mehrfach gestartet, aber nicht abgeschlossen. Der Lauf blieb im bestehenden Akquisepfad bei der Kandidatenaufbereitung CPU-gebunden; ein PowerShell-Trace zeigte `New-JobAgentCoverageCandidateReviewQueueEntry` / Kandidatenaufbereitung. Daraus ist kein Produktfehler von JA-055 abgeleitet. Zuerst den konkreten Akquise-Teiltest mit der kleinen Daily-Run-Fixture isolieren; erst dann einen produktiven oder testseitigen Fix vornehmen.

Die noch nicht als feste JA-055-Wahrheitstabelle belegten Fälle sind: Job/Firma/Job+Firma/keine Ausblendung in allen drei Sichtbarkeitsmodi, Reload, Speicherfehler, Importkonflikt, neue Stelle einer ausgeblendeten Firma sowie getrennte IDs bei gleichen Namen. Danach `docs/test-matrix.*` und das Funktionsinventar aktualisieren.

Ein Supertest wurde nicht angefordert und gilt für diesen Übergabestand als erledigt; er ist kein Restpunkt und wird nicht nachträglich ausgeführt.

## Danach

Wenn JA-055 mit dem offenen Daily-Run-Nachweis abgeschlossen ist, vollständig nach `Roadmap_archive.md` rotieren, `TD-0082` schließen und mit `JA-049` fortsetzen. JA-049 verlangt einen atomar publizierten Einstieg `html/jobagent/index.html`, gemeinsame Storegeneration für Stellen/Firmen/Coverage und Erhalt der bestehenden Coverage-/Archivpfade.

`TD-0085` ist unabhängig: `route_ok=false` wird ausschließlich durch bestehende Steuerzeichen bzw. eine offene Markdown-Fence in gebündelten Sonar-JRE-Lizenzdateien ausgelöst. Diese Dateien nicht im Rahmen der Produktroadmap verändern.
