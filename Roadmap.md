# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das produktive Firmeninventar enthaelt aktuell nur 38 Arbeitgeber. Fuer das Ziel "alle Muenchner und Freisinger Firmen" fehlt eine skalierbare Kandidatenbasis aus Register-, Regional- und Jobboersenquellen; Vollstaendigkeit, Lizenz-/Nutzungsgrenzen, Deduplikation, Standortbezug und offizielle Karriereverifikation sind noch nicht belastbar operationalisiert.
- Priorisierung: Zuerst muessen Quellenrecht, Source Registry, Rate-Limits und Evidenzvertrag stabil sein, danach werden massentaugliche Register-/Regional-/Jobboersen-Hinweise importiert, anschliessend werden Kandidaten dedupliziert und standortbezogen bewertet, danach werden offizielle Firmen-/Karriere-/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store in Wellen auf tausende Firmen erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- (keine aktiven Punkte)


