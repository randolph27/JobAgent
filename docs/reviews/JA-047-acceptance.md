# JA-047 – Akzeptanznachweis

Stand: 2026-09-17

## Ergebnis

Die Stellenansicht verwendet einen gemeinsamen, deterministischen Resolver fuer Freitext, Facetten, Sortierung, persoenliche Browserzustandsfilter, URL-Hash und 50er-Pagination. Unbekannte Arbeitgeber- und Kategorienwerte werden aus dem kanonischen Hash entfernt. Ein unbekannter Gebietswert bleibt als aktive, leere Gebietsabfrage erhalten; dadurch wird eine fehlerhafte URL nicht still zu einer breiten Suche erweitert.

## Belegter Umfang

- 264 Stellen und 251 Firmen aus der isolierten Fixture; alle sechs Seiten sind mit exakten IDs erreichbar.
- UND zwischen Facetten sowie ODER innerhalb einer Mehrfachauswahl, Mehrorttreffer, `UNKNOWN`, Altersgrenzen, Umlaute, Sonderzeichen und Sortiergleichstaende sind abgenommen.
- Hash-Reload, Zurueck/Vor, Reset, Filterchips, Tastaturfokus, mobile und Desktop-Viewports sowie die browserlokalen Favoriten-/Bewerbungsfilter sind abgenommen.
- Die Browserinteraktion hat weder die Fixture noch den HTML-Report geaendert. Es gab keine Job-API-, Daily-Run- oder Store-Anfrage. Die bekannte Kaspersky-Telemetrie ist als Umgebungsrequest getrennt dokumentiert; unerwartete Hosts und Browserfehler sind leer.

## Evidence

- Browserlauf: `logs/jobagent/QA-004/qa004-2580bdbef1f147a4b88750bf6a5091c4/browser-cases.json`
- Filtermatrix: `logs/jobagent/JA-047/filter-matrix.json`
- Screenshots: `logs/jobagent/QA-004/qa004-2580bdbef1f147a4b88750bf6a5091c4/playwright/ui-001-browser-audit-{390,800,1366,1920}.png`
- Fixture-SHA-256: `aa28bbf60c39aad0d00e7f7161e3bf6102d679bafd643452eb4e32ae5850f17c`
- HTML-SHA-256 vor/nach Interaktion: `72d3d057727a0ade905ff644b1f5c14da16558fbdd795efe16aebc217f4f8b2e`

## Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` – Exit 0

Der Abschluss-Supertest wurde gemaess Nutzeranweisung nicht ausgefuehrt.
