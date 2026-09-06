# Übergabe – CI-001 abgeschlossen, JA-027 aktiv

Stand: 2026-09-06. Arbeitsbranch: `master`.

## Abgeschlossen

`CI-001 – Projektbezogene CI- und Reviewnachweise verlässlich machen` ist nach `Roadmap_archive.md` rotiert. `TD-0052` ist abgeschlossen; `TD-0041` / `JA-027` ist der einzige aktive Todo-Punkt.

### Implementierung

1. `.ci/bin/modules/browser-logic.ps1` prüft Listener vor dem Start. Bestehende verwaltete und fremde Listener auf Port 8500 werden getrennt ausgewiesen; fremde Prozesse werden weder beendet noch als CI-eigen ausgegeben. Devserver-Logs erhalten pro Start einen Zeitstempel. PID-Dateien speichern Launcher-, Listener- und Startzeitidentität.
2. `.ci/bin/modules/verify-logic.ps1` überspringt nur die projektgebundene mutable Datei `Roadmap.md` bei der Immutable-Prüfung. Alle anderen gepinnten Dateien bleiben hashgeprüft. Die neue Konfiguration ist mit ihrem konkreten SHA-256 in `.ci/pins/immutable.hashes.json` hinterlegt.
3. `.ci/ci.config.json` nutzt als Verify-Lane den neuen CI-Vertragstest. Sonar ist explizit `not-supported`: Für PowerShell und statisches HTML existiert kein konfigurierter Scanner. Der SonarQube-Serverstatus wird nicht als Analyse- oder Quality-Gate-Pass ausgegeben.
4. `tests/Test-JobAgentHtmlViewportAudit.ps1` unterscheidet Fixture und Produktionsreport. Es erzeugt Artefakte für 1920, 1366, 800 und 390 px; der Produktionsreport ist `html/jobagent/company-coverage.html`.

## Aktuelle Evidence

- `logs/terminal/self-check-20260906-080449.log` – `self-check` Exit 0.
- `logs/terminal/route-check-20260906-080445.log` – `route-check` Exit 0.
- `logs/verify/verify-20260906-075205.log` – Verify Exit 0.
- `logs/jobagent/ja-022-viewport-audit.json` – Fixture klar als `synthetic_fixture`; Produktionsreport HTTP 200.
- `output/playwright/ja-022-production-coverage-viewport-{1920,1366,800,390}.png` – Browserartefakte.

## Verifikation

Erfolgreich:

- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1`
- `.\ci.cmd verify`
- `.\ci.cmd sonar` – Exit 0, Status `not-supported`, keine Analyse behauptet
- `.\ci.cmd self-check`
- `.\ci.cmd route-check`
- `git diff --check`

Der angeforderte Supertest wurde gestartet, erreichte jedoch keinen Abschluss. Untergeordnete `Test-JobAgentDailyRun.ps1`- und `Test-JobAgentReport.ps1`-Prozesse blieben hängen; ausschließlich diese anhand ihrer Kommandozeilen verifizierten Testprozesse wurden beendet. Es gibt keinen grünen Supertest-Nachweis. Vor einem erneuten Lauf zuerst `Test-JobAgentDailyRun.ps1` isoliert mit kontrolliertem Timeout analysieren; keine weiteren parallelen Supertest-Prozesse starten.

## Nächster Arbeitsschnitt: JA-027

Ziel ist ein zusammenhängender, wiederaufnehmbarer Akquise-Slice für mindestens 1.000 eindeutig belegte Karriere-/ATS-Quellen. Einstieg und Vertrag stehen in `Roadmap.md` unter `JA-027`.

Priorisierte Umsetzung:

1. Website-/Domainhinweise aus `JobAgent.RegionalDiscovery.psm1` mit Provenienz erhalten; Hinweise bleiben unverifiziert.
2. Offizielle Firmen-, Karriere- und ATS-Belege inklusive Redirects und iframes verifizieren; nicht eindeutige Fälle in Review belassen.
3. Workerpool mit Host-/ATS-Limits, Retry-After, Backoff, Resume und atomarem seriellem Writer implementieren.
4. Zunächst einen 100-Kandidaten-Benchmark ausführen; Durchsatz, P50/P95, Fehler- und Reviewquote belegen, erst danach skalieren.

No-Gos: keine erfundenen Firmen oder Karriere-URLs, keine Sekundärquelle als offizielle Karriereverifikation, keine unkontrollierten Massenwrites, kein paralleler Store-Writer.
