# JA-053 – Quellenchronik

Stand: 2026-09-18

Die Detailansicht projiziert Change-Events ausschliesslich je stabiler `job_id`. Die Browserfixture belegt den Leerzustand sowie 21 Ereignisse: anfangs 20 sichtbar, ein klar beschrifteter Aufklappbutton fuer den restlichen Eintrag, Vorher/Nachher als Klartext und Tastaturbedienung eines Eintrags. Fehlende Altsnapshots bleiben als nicht archiviert markiert; Quell-HTML wird nicht ausgefuehrt.

## Nachweise

- Fixture: `tests/fixtures/jobagent/job-change-history.json`
- Browser-Evidence: `logs/jobagent/JA-053/change-cases.json`, Supertest-Lauf `ja053-583c16a0e7a6491ca27a0dfc5f8b15d7`
- Screenshot: `doc/roadmap-screenshots/JA-053-change-detail-1366.png`, SHA-256 `f98b88268f9fb0537f8ff560abe3596b11eb04aa879a862828a618abb041f011`
- Lokaler Browser: 0 Browserfehler, keine Report-initiierten externen Anfragen; der Kaspersky-Webschutz wird als Umgebungsverkehr ausgeschlossen.

## Funktionstests

- `Test-JobAgentChangeHistory.ps1`: bestanden.
- `Test-JobAgentStatusMachine.ps1`: bestanden.
- `Test-JobAgentPersistence.ps1`: bestanden.
- `Test-JobAgentReport.ps1`: bestanden.
- `Test-JobAgentChangeHistoryBrowserAudit.ps1`: bestanden; 1920/1366/800/390 CSS-Pixel ohne horizontalen Ueberlauf oder Summary-Clipping.
- `Test-JobAgentTestMatrix.ps1`: bestanden; Inventar mit 601 Eintraegen und 10 Matrixfaellen synchron.

## Abschlussgate

`./ci.cmd supertest` ist bestanden: 32 von 32 Faellen bestanden, 0 fehlgeschlagen, 0 blockiert und 0 nicht ausgefuehrt. Der erste Lauf legte einen Daily-Run-Determinismusfehler offen: dynamische Change-Event-IDs fehlten in der Hashnormalisierung des Tests. `Test-JobAgentDailyRun.ps1` normalisiert nun auch das Praefix `change:`; der fokussierte Test und der anschliessende Vollsupertest sind gruen.
