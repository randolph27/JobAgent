# JA-055 – Abnahme: reversible Ausblendungen

Stand: 2026-09-18

Die lokale Ausblendung ist auf stabile Job- und Firmen-IDs begrenzt. Sie entfernt weder Stellen noch Arbeitgeber aus dem publizierten Bestand und verändert keine Quelldaten.

Abgenommen:

- Job- und Firmenausblendung mit Grund, optionalem Text und sofortigem Rückgängig.
- Firmenvorrang bleibt nach Wiederherstellung einer einzelnen Stelle sichtbar und bedienbar.
- Die Modi `visible`, `all` und `hidden` liefern getrennte Ansichten; der Zähler zählt eine Job- und Firmenausblendung nicht doppelt.
- Favoriten und Bewerbungen bleiben in der persönlichen Anzeige sichtbar.
- v2-Speicherung, Reload, Import-Zeitvergleich, Quota-Fehler und ID-Trennung sind durch den UserState-Test abgedeckt.
- Die Verwaltungsansicht erfüllt bei 390, 800, 1366 und 1920 CSS-Pixeln die Geometrieprüfung ohne Überlappung, horizontalen Overflow oder zu kleine Controls.

Nachweise:

- `logs/jobagent/JA-055/visibility-cases.json`
- `doc/roadmap-screenshots/JA-055-hidden-management-390.png`
- `logs/jobagent/QA-004/qa004-26c1b1372bbf498cac8ed7ee6377f626/browser-cases.json`

Funktionstests:

```text
pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1                 -> Exit 0
pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1                    -> Exit 0
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1                  -> Exit 0
pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1            -> Exit 0
pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly -> Exit 0
```

Das Browserumfeld lädt eine Kaspersky-Web-Anti-Virus-Injektion. Der gezielte Sichtbarkeitstest verwirft diese bekannte Umgebungsanfrage; fachliche Bedienung startet keine Anwendungskommunikation nach außen.
