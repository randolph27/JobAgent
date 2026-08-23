# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-016 ist weitgehend fachlich angelegt, aber die angehängte Programmanweisung ist noch nicht vollständig umgesetzt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizielle Quellenverifikation, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog und Supertest.
- Kritische Lücken: Live-Recherche bleibt trotz robusterer Adapter begrenzt; lokale App-/Artefaktablage, Devserver-Portvertrag und Visual-Audit-Nachweise sind noch nicht vollständig vertraglich abgesichert.
- Priorisierung: nach abgeschlossener Firmenabdeckung folgt jetzt die lokale Betriebs-/Audit-Härtung, weil HTML-Artefakte bereits existieren, aber Port-, Ablage- und Sichtbarkeitsvertrag noch offen sind.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktuell keine offenen Punkte

- Alle bisherigen Roadmap-Punkte bis `JA-022` sind archiviert.
- Naechster Chat startet von `Roadmap_archive.md`, `handoff.latest.md` und den erzeugten JA-022-Audit-Artefakten aus `html/jobagent/`, `logs/jobagent/` und `output/playwright/`.
