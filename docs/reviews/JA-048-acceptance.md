# JA-048 – Akzeptanznachweis

Stand: 2026-09-18

## Ergebnis

Stellendetails zeigen die kanonische `job_id`-Projektion mit getrennten, browserlokalen Favoriten- und Bewerbungsmarkierungen. Die Rueckkehr aus einer sichtbaren Trefferkarte behaelt den Seitenkontext und setzt den Tastaturfokus wieder auf ihren Stellentitel. Unbekannte Detail-IDs zeigen einen sicheren Leerzustand; historische Markierungen bleiben als nicht aktuelle Referenzen getrennt sichtbar.

## Belegter Umfang

- Detailansicht: Hash, Detailfelder, sichere Links, unbekannte ID, Ruecknavigation und Rueckfokus sind in der isolierten 264-Stellen-/251-Firmen-Fixture belegt.
- Markierungen: Favorit und Bewerbung aendern nur ihr eigenes Feld, bleiben zwischen Detail und Trefferkarte synchron, verwenden eindeutige Texte und `aria-pressed` und erzeugen keine Navigation oder externe Produktanfrage.
- Bedienung: Der Test durchlaeuft den Tastaturweg ueber eine sichtbare Trefferkarte auf Seite 6, oeffnet mit Enter, markiert separat und kehrt per Trefferlistenaktion mit Fokus auf den Ursprungstitel zurueck.
- Integritaet: Fixture- und Reporthash sind vor/nach der Browserinteraktion identisch. Browserfehler und unerwartete externe Hosts sind leer; die alleinige Kaspersky-Telemetrie ist als Umgebungsrequest dokumentiert.

## Evidence

- Browserlauf: `logs/jobagent/QA-004/qa004-fe149db5721742debe31a682b8ef44a7/browser-cases.json`
- Interaktionsmatrix: `logs/jobagent/JA-048/interaction-cases.json`
- Detailscreenshot, 1366 Pixel: `doc/roadmap-screenshots/JA-048-detail-1366.png` (SHA-256 `cc00a3730b78f37a43717e201b27a459ad7d3ae9088c674f83d7806002b75694`)
- Sternescreenshot, 390 Pixel: `doc/roadmap-screenshots/JA-048-stars-390.png` (SHA-256 `45b553678a3840160c2e0ffb660609cd1fd4f5aaf2eaae8652bb8fef622c8e04`)
- Fixture-SHA-256 vor/nach Interaktion: `aa28bbf60c39aad0d00e7f7161e3bf6102d679bafd643452eb4e32ae5850f17c`
- HTML-SHA-256 vor/nach Interaktion: `afc51cb2a3cb0e31f84f8da499a0162024c897971beda949841593aec275386c`

## Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` – Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1 -WriteInventory` – Exit 0, 592 Inventareintraege
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1` – Exit 0
- `.\ci.cmd supertest` – Exit 0; 30 geplant, 30 bestanden, 0 fehlgeschlagen, 0 blockiert, 0 nicht ausgefuehrt.

Der erste Abschlusslauf scheiterte ausschliesslich am veralteten QA-001-Funktionsinventar. Nach kanonischer Neuerzeugung mit dem vorgesehenen Matrixgenerator ist der Wiederholungslauf vollstaendig gruen.
