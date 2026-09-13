# Planungsabschluss: automatische Firmenbasis und allgemeine Suche

Stand: 2026-09-13T14:27:37+02:00

## Ergebnis

Vier priorisierte Roadmap-Punkte, jeweils genau drei detaillierte Unterpunkte mit je drei Umsetzungsschritten:

1. JA-027: Neue Firmen beim regulaeren Jobstart automatisch entdecken, Website und Karriere-/Jobs-/Stellenangebote-Unterseite oder offizielles ATS belegen, dauerhaft speichern und im WebIF anzeigen. Kein separater manueller Akquise-/Reportcommand.
2. JA-041: Allgemeine Stellenerfassung ohne feste IT-Fuehrungsbegriffe; Berufsprofile beeinflussen nur die Auswahl/Anzeige. Vorhandene Parserarbeit erhalten, alte Profilrejection nicht blind migrieren.
3. UI-001: Alle Firmen/Stellen erreichbar; Freitext, Beruf/Profil, Arbeitgeber, Gebiet, Arbeitsmodell, Anstellungsart, Arbeitszeit und Aktualitaet. Filter lokal auf gesamtem Bestand, ohne Jobstart/HTTP.
4. JA-042: Startintegration, Budgets, Resume, Wiederholung und atomare WebIF-Publikation pruefen. Keine reale Firmenmindestmenge als Roadmap-Abnahme.

Muenchen mit bestehendem 20-km-Bereich und Freising bleiben unveraendert. Fuer Freising wurde kein neuer Radius angenommen. Firmengebiet und Stellenort getrennt. Der alte Programmvertrag ist bei Umsetzung zu synchronisieren; die aktuelle Nutzerkorrektur hat Vorrang.

Nur Roadmap und notwendige Zustands-/Handoff-Artefakte geaendert. Kein Produktionscode, keine Produktivdaten und kein Liveakquiselauf. Der Originalplan mit kompletter Fortschrittshistorie bleibt unter docs/reviews/2026-09-13-ja027-roadmap-before.md erhalten; seine alten IT-/Mengenziele sind historisch, nicht mehr aktuell. Die Firmenakquise wird nach spaeterer Implementierung durch normale Benutzerlaeufe ausgefuehrt, nicht durch manuelle Chat-Abfragewellen.

## Verifikation

- Aktueller Struktur-/Hash-/State-Nachweis: docs/reviews/2026-09-13-ja027-plan-validation.json.
- Test-JobAgentCiContracts.ps1: Exit 0, sieben Vertragsfaelle.
- ci.cmd route-check und ci.cmd stp: Exit 0.
- Keine Supertest-/Browser-/Device-/Sonar-Ausfuehrung: nur Plan, keine Runtime-/UI-Aenderung.
- Self-check vor den urspruenglichen Aenderungen: Exit 1, 45 Altbefunde (44 fehlende Eventfelder, ein Checkpoint-State-Konflikt). Historische Eventinhalte unveraendert; diese Legacy-Fehler wurden nicht als gruene Gesamtpruefung dargestellt.
- Legacy-STP ordnet aktive JA-027-Events wegen wiederverwendeter Archiv-ID falsch done zu. Betroffene Sessionevents unveraendert in aktiver History erhalten, Digest gegen aktiven Index korrigiert; aktueller Checkpoint mit exakter neuer Eventgrenze und State synchronisiert. Kein CI-Runtimefix im Planungsumfang.
- Git-Whitespacepruefung: nur geerbte Leerzeilen am Dateiende der bewusst unveraenderten Originalplankopie; alle anderen Whitespacepruefungen gruen.

## Naechster Anker

JA-027: vorhandene Retention pruefen; Neufirmenakquise mit Website/Karrierequelle in regulaeren Daily-Start integrieren und Firmen im WebIF anzeigen. Keine manuellen Firmenmengenwellen.

Keine Implementierung in diesem Auftrag. Aktiver TD-0041/JA-027 bleibt offen; in-progress bezeichnet den laufenden Gesamtpunkt. Nach geprueftem Planungsabschluss nur Commit/Push und Stop. Der Git-Snapshot im generierten Handoff ist der Stand vor Commit, kein Nachweis eines bereits sauberen gepushten Worktrees.
