# JA-050 – Akzeptanznachweis (Teilbild 1)

Stand: 2026-09-18T22:48:38+02:00

## Ausgefuehrte deterministische Fixture

Command:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentAcceptance.ps1
```

Ergebnis: Exit 0

```json
{
  "status": "ok",
  "companies": 4,
  "historical_jobs": 4,
  "open_jobs": 3
}
```

Der Lauf prueft: Firmen- und Stellenwachstum von 3 auf 4, A1-Aktualisierung, Schliessung von A2 nach vollstaendig erfolgreichem Leerscan, Erhalt von B1 bei Quellenfehler, browserlokale Favoriten- und Bewerbungsmarkierungen, A2-Notiz mit offener Nachfassaufgabe sowie C1-Ausblendung und generationengebundene Sichtung einer gespeicherten Suche.

## Reproduzierbarkeitsbindung

| Artefakt | SHA-256 |
|---|---|
| `tests/Test-JobAgentAcceptance.ps1` | `c79c83cf255baa52187557b96342c5121f5b0d5545761d96e614186347877e03` |
| `docs/test-matrix.json` | `8e6bf67a1e6d0a1dd74f76556d11b3ccd56b8f1c1cf60485db46e83bd0dc13d9` |
| `html/jobagent/assets/jobboard-state.js` | `c7472f3a7323558f6213daf7da2e4e53f1b5c6d083cc504e2dc19cab264e3323` |

## Noch offen

JA-050 bleibt aktiv. Browser-/Viewport-, Kalender-, Export-/Import- und Lastmessungen aus Teilbild 2 und 3 sind mit diesem Teilnachweis nicht abgenommen. Der Supertest ist nicht angefragt und gilt gemaess Nutzerauftrag als erledigt; er wurde nicht ausgefuehrt.

## Teilbild 2 – gezielte lokale Browsernachweise

Stand: 2026-09-21T13:08:14+02:00

Die folgenden isolierten Browserfaelle wurden gegen den lokalen CI-Devserver auf Port 8500 ausgefuehrt. Die Tests verwenden keine persoenlichen Browserdaten. Die von Kaspersky injizierten Requests an `gc.kis.v2.scr.kaspersky-labs.com` sind in den Artefakten als Umgebungsereignisse getrennt ausgewiesen und wurden nicht dem Report zugerechnet.

| Command | Ergebnis | Nachweis |
|---|---|---|
| `pwsh -NoProfile -File .\tests\Test-JobAgentCalendarBrowserAudit.ps1` | Exit 0 | `logs/jobagent/JA-054/ja054-calendar-0e585975e4d44985b4451f4e6eda94c5/calendar-browser-cases.json` |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -ApplicationOverviewOnly` | Exit 0 | `logs/jobagent/QA-004/qa004-04db5e8e220f44018b4be5563fb685bf/browser-cases.json` |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -SavedSearchOnly` | Exit 0 | `logs/jobagent/QA-004/qa004-aa31930924114a158e915319433443a2/browser-cases.json` |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` | Exit 0 | `logs/jobagent/QA-004/qa004-b40c6d48f02840278954fa004059d719/browser-cases.json` |
| `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` | Exit 0 | Konsolennachweis: v1->v2-Migration, Export/Reload, Importvorschau, Termin-/Notiz- und Ausblendungsfaelle |
| `pwsh -NoProfile -File .\tests\Test-JobAgentSavedSearches.ps1` | Exit 0 | Konsolennachweis: generationengebundene neue/geaenderte Treffer und explizite Sichtung |
| `pwsh -NoProfile -File .\tests\Test-JobAgentAcceptance.ps1` | Exit 0 | `logs/jobagent/JA-050/acceptance-latest.log` |

Die gezielten Faelle belegen Kalenderansichten, Tastaturpfad und vier Viewports; lokale Stufen-, Notiz-, Termin- und Fälligkeitsfilter; gespeicherte Suche mit expliziter Sichtung; Ausblendung mit Grund, Rueckgaengig und Firmenvorrang sowie die v1->v2- und Export-/Import-Vertraege. Der noch ausstehende Massentest und die abschliessende, zusammengeführte Browserreise bleiben Teilbild 3 beziehungsweise der verbleibende Anteil von Teilbild 2.
