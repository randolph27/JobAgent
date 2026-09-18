# JA-055 – Ausblendungen: Zwischenstand

Stand: 2026-09-18

## Belegte Funktion

- Browserlokale Ausblendungen für einzelne Stellen und Arbeitgeber sind über stabile IDs gespeichert. Grund und Freitext bleiben lokal.
- Wiederherstellen wirkt sofort. Eine wieder eingeblendete Stelle bleibt bei ausgeblendetem Arbeitgeber sichtbar als durch den Arbeitgeber verborgen; die Arbeitgeberaktion bleibt erreichbar.
- Die Verwaltungsansicht zeigt auch Ausblendungen, deren IDs im aktuellen Report nicht vorkommen. Der Zähler erfasst eine Stelle mit Job- und Arbeitgeberausblendung nur einmal.
- Favoriten und Bewerbungen werden vom Standardfilter nicht ausgeschlossen.

## Evidence

- [Sichtbarkeitsfälle](../../logs/jobagent/JA-055/visibility-cases.json): `262` sichtbare und `2` ausgeschlossene Stellen, Grund `ROLE`, Text, Rückgängig, Arbeitgebervorrang und zurückgesetzter Sichtbarkeitsfilter.
- [Mobile Verwaltungsansicht](../../doc/roadmap-screenshots/JA-055-hidden-management-390.png): SHA-256 `36ad4ee1826776f78871ae399f8b82fbd5c74dda1be1d934a043f0b274de266d`.
- Die Viewportmessungen für 390×844, 800×1024, 1366×768 und 1920×1080 enthalten keinen horizontalen Overflow, keine überlappenden Controls, keine zu kleinen Controls und keinen abgeschnittenen Text.

## Ausgeführte Funktionstests

| Befehl | Ergebnis |
| --- | --- |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` | erfolgreich |
| `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` | erfolgreich |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` | erfolgreich |

## Offen

`Test-JobAgentDailyRun.ps1` ist weiterhin nicht abgeschlossen: Der bestehende Akquise-Funktionstest bleibt bei der Kandidatenaufbereitung CPU-gebunden und lieferte innerhalb des beobachteten Zeitfensters kein Ergebnis. Der Test ist nicht durch JA-055 geändert worden; bis zu seiner reproduzierbaren Klärung bleibt JA-055 offen. Kein Supertest wurde ausgeführt.
