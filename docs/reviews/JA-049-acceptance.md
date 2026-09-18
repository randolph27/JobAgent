# JA-049 – Publikationsnachweis

Stand: 2026-09-18

- Stabiler Einstieg: `http://127.0.0.1:8500/html/jobagent/` liefert HTTP 200, die Stellenansicht und den Rücklink zur Coverage-Diagnose.
- Generationsbindung: `html/jobagent/index.html` wird aus einem validierten HTML-Report bytegleich atomar veröffentlicht. Das Manifest `logs/jobagent/JA-049/publication-manifest.json` enthält Scan-ID, Storepfad und SHA-256-Hashes für Store, Quellreport und Einstieg.
- Fehlergrenze: Der Testfall `interrupted_publish_preserves_previous_entry` unterbricht vor dem Austausch und bestätigt, dass die vorherige Startseite unverändert bleibt.

Funktionstests: `Test-JobAgentPublication`, `Test-JobAgentDailyRun`, `Test-JobAgentOperations`, `Test-JobAgentCoverage -IncludeToolIntegration`, `Test-JobAgentCiContracts` und `Test-JobAgentHtmlViewportAudit` erfolgreich. Der Abschluss-Supertest läuft noch; erst sein Ergebnis entscheidet über die Roadmap-Rotation.
