# JA-056 – Akzeptanz

Stand: 2026-09-18

Der lokale Suchauftragsablauf verwendet ausschließlich den kanonischen Filterresolver des Reports. Speichern, Aufrufen, Bearbeiten, Duplizieren, Löschen und die explizite Sichtungsbestätigung sind getrennte Aktionen. Der Sichtungsstand wird nur nach erfolgreicher lokaler Speicherung für die geladene Reportgeneration ersetzt.

## Belegte Fälle

- Erstes Speichern setzt den aktuellen sichtbaren Bestand als Baseline; der Vergleich zeigt danach null neue und null fachlich geänderte Treffer.
- Ein neuer Job und ein neues fachliches Ereignis eines bekannten Jobs werden getrennt als „Neu in dieser Suche“ beziehungsweise „Fachlich geändert“ ausgewiesen.
- Ein nur durch eine lokale persönliche Auswahl sichtbarer Treffer bleibt von Stellenfunden getrennt.
- Normalisierte Doppelnamen, 51. Auftrag, 81 Unicode-Codepoints, ungültige Vergleichsgeneration und ein Speicherfehler lassen den vorherigen Zustand unverändert.
- Export und erneutes Laden erhalten Suchaufträge und Baselines. Die UI-Aktionen erzeugen keine Produktnetzwerkanfrage.

## Evidence

- [Fallprotokoll](../../logs/jobagent/JA-056/saved-search-cases.json)
- [Desktop-Ansicht](../../doc/roadmap-screenshots/JA-056-search-overview-1366.png)
- [Mobile Ansicht](../../doc/roadmap-screenshots/JA-056-new-results-390.png)

## Ausgeführte Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentSavedSearches.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -SavedSearchOnly` – Exit 0

Die Browserumgebung löste eine Anfrage an `gc.kis.v2.scr.kaspersky-labs.com` aus. Sie stammt nicht aus dem Report und ist als Umgebungsartefakt vom Produktnetzwerkassertion getrennt.
