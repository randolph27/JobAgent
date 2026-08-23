# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das Firmeninventar enthaelt erst 20 Arbeitgeber; Vollstaendigkeit ist unbelegt. Die Recherchequellen fuer Muenchen, 20-km-Umkreis und Freising sind noch nicht als deterministische Source Registry, Import-Lane, Verifikations-Lane und Coverage-Audit operationalisiert.
- Priorisierung: Zuerst muessen Quellenkategorien und Evidenzvertrag stabil sein, danach werden offizielle regionale Listen und oeffentliche Jobdaten als Discovery-Hinweise importiert, anschliessend werden Karriere-URLs/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store breit erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

_Keine aktiven Punkte._
