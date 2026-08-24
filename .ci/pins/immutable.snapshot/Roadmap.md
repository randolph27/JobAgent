# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das produktive Firmeninventar enthaelt aktuell nur 38 Arbeitgeber. Fuer das Ziel "alle Muenchner und Freisinger Firmen" fehlt eine skalierbare Kandidatenbasis aus Register-, Regional- und Jobboersenquellen; Vollstaendigkeit, Lizenz-/Nutzungsgrenzen, Deduplikation, Standortbezug und offizielle Karriereverifikation sind noch nicht belastbar operationalisiert.
- Priorisierung: Zuerst muessen Quellenrecht, Source Registry, Rate-Limits und Evidenzvertrag stabil sein, danach werden massentaugliche Register-/Regional-/Jobboersen-Hinweise importiert, anschliessend werden Kandidaten dedupliziert und standortbezogen bewertet, danach werden offizielle Firmen-/Karriere-/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store in Wellen auf tausende Firmen erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- [ ] JA-032 Coverage-HTML mit anklickbaren Anbieter-, Karriere- und ATS-Links ausgeben #comment: Der lokale HTML-Output muss neben Statistiken direkt nutzbare Links enthalten, damit der Nutzer aus dem Bericht zur Anbieterquelle springen kann.
  - [ ] Beschreibung: `html/jobagent/company-coverage.html` soll im Firmeninventar, Backlog, Scanprioritaeten, Importwellen-Kandidaten und Kandidaten-Freshness anklickbare Links anzeigen. Primaere Links fuehren bevorzugt zur verifizierten Karriere-URL, danach zur offiziellen Website, danach zur offiziell belegten ATS-Quelle; unverifizierte Discovery-Hints erscheinen nur mit Review-Kennzeichnung und nicht als produktive Anbieterquelle. Linkzellen muessen auch bei langen URLs mobil und desktop-tauglich bleiben, keine Tabellen sprengen und externe Ressourcen weiterhin vermeiden.
  - [ ] Scope: Erweitert werden `tools/Measure-JobAgentCompanyCoverage.ps1`, `html/jobagent/company-coverage.html`, `tests/Test-JobAgentCoverage.ps1`, `tests/Test-JobAgentHtmlAudit.ps1` und optional `tests/Test-JobAgentHtmlViewportAudit.ps1`. No-Go: kein JavaScript-Zwang fuer Grundfunktion, keine externen Stylesheets/Skripte, keine verdeckten Redirects, keine Links in Statistikkarten ohne Kontext.
  - [ ] Ist-Stand (2026-08-23 12:30): Der Coverage-HTML-Report wurde erzeugt und zeigt Coverage-Statistiken, Importwellen und Tabellen; im aktuell sichtbaren Nutzen fehlen anklickbare Links, die direkt zur Anbieter-/Karrierequelle fuehren.
  - [ ] Abhängigkeiten: JA-031 muss den Linkvertrag und die zentrale Linkauswahl liefern; JA-030 liefert Freshness- und Coverage-Struktur.
  - [ ] Aufwand/Dauer: Aufwand M, Dauer 0.5-1 PT bei 1 Entwickler/Agent; HTML-Renderer und Tests sind eng gekoppelt und sollten im selben Arbeitsschnitt umgesetzt werden.
  - [ ] Prioritätsscore: 90/100, weil dies die direkt sichtbare Nutzeranforderung im lokalen HTML-Artefakt erfuellt.
  - [ ] Ordnungsbegründung: Nach dem Datenvertrag folgt die konkrete HTML-Ausgabe, damit alle Linkentscheidungen aus einer Quelle kommen und nicht im Renderer dupliziert werden.
  - [ ] Risiken und Unsicherheiten: Lange URLs koennen Layoutprobleme erzeugen; Firmen koennen mehrere offizielle Links haben; `target=_blank` braucht sichere `rel`-Attribute; Review-Hints duerfen nicht wie verifizierte Anbieterlinks wirken.
  - [ ] Schritte:
    1. Tabellen erweitern: In `ConvertTo-ToolCoverageHtml` und `ConvertTo-ToolCoverageMarkdown` Linkspalten fuer Firmeninventar, Backlog, Scanprioritaeten und Importwellen-Kandidaten ergaenzen; Linktext kurz halten (`Karriere`, `Website`, `ATS`, `Review-Hinweis`) und URL als `href` setzen.
    2. HTML-Sicherheit und Layout absichern: `rel="noopener noreferrer"`, HTML-Encoding, `overflow-wrap:anywhere`, horizontale Scrollcontainer und Sticky-Header beibehalten; Links duerfen Tabellen nicht verbreitern oder Text ueberlagern.
    3. Report-Artefakt pruefen: `tests\Test-JobAgentCoverage.ps1` muss erzeugtes HTML auf `<a href=...>`, offizielle Beispiel-URLs, fehlende externe Skripte/Stylesheets und Review-Hinweis-Markierung pruefen; optional visueller Audit fuer 1920/1366/800.
  - [ ] Evidence: Aktualisiertes `html/jobagent/company-coverage.html` mit klickbaren Links; Coverage-Markdown mit Linkspalten; Testausgabe aus `tests\Test-JobAgentCoverage.ps1`; optional neue Screenshots unter `output/playwright/`.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; bei HTML-/Viewport-Aenderung zusaetzlich `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1`.
  - [ ] Audit: Im Browser pruefen, dass mindestens Firmen mit Karriere-URL anklickbare Links haben, dass Links sichtbar als Website/Karriere/ATS gekennzeichnet sind, dass Tabellen auf 1920/1366/800 nicht ueberlaufen und dass kein Link zu Jobboersen als offizieller Anbieterlink dargestellt wird.
  - [ ] Supertest: Erst nach gruenen Funktionstests `.\ci.cmd supertest`; Abschluss nur bei Exit 0.

- [ ] JA-033 Daily-Run-HTML und Detailberichte mit klickbaren offiziellen Stellen- und Anbieterlinks vereinheitlichen #comment: Nicht nur Coverage, sondern auch Daily-Run-Berichte sollen aus jeder relevanten Ergebniszeile direkt zur offiziellen Quelle fuehren.
  - [ ] Beschreibung: Daily-Run-Markdown und Daily-Run-HTML sollen fuer neue, aktive, geaenderte und entfernte passende Stellen sowie fuer Fehler-/Quellen-Sektionen klickbare offizielle Links konsistent anzeigen. Stellenlinks nutzen `official_url`; Anbieterlinks nutzen den Linkvertrag aus JA-031. Fehlerhafte oder nicht erreichbare Quellen zeigen anklickbare Quell-URLs nur dann, wenn sie als offizielle JobSource im Store stehen; ansonsten erscheint ein nicht klickbarer Review-Grund.
  - [ ] Scope: Erweitert werden `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentDailyRun.ps1` und vorhandene HTML-/Markdown-Artefaktpruefungen. No-Go: keine Bewerbungsaktion, kein Formular-Autofill, keine Linkausgabe fuer ungesicherte Aggregator-URLs als offizielle Stelle, keine neue Live-Abhaengigkeit im Test.
  - [ ] Ist-Stand (2026-08-23 12:30): Daily-Run-Reports enthalten bereits stellenbezogene URLs in Tabellen, aber Anbieter-/Karriere-Links sind nicht als einheitlicher, getesteter Linkvertrag ueber alle Report-Sektionen abgesichert.
  - [ ] Abhängigkeiten: JA-031 muss zentrale Linkobjekte bereitstellen; JA-032 kann parallel umgesetzt werden, solange der gemeinsame Linkvertrag stabil ist.
  - [ ] Aufwand/Dauer: Aufwand M, Dauer 0.5-1.5 PT bei 1 Entwickler/Agent; Report- und DailyRun-Tests muessen beide laufen, weil JSON-/Markdown-/HTML-Artefakte gemeinsam betroffen sind.
  - [ ] Prioritätsscore: 82/100, weil Coverage-Links zuerst den gemeldeten Mangel beheben, Daily-Run-Links aber fuer den taeglichen Arbeitsfluss denselben Nutzen bringen.
  - [ ] Ordnungsbegründung: Nach Coverage-HTML folgt die Vereinheitlichung der Daily-Run-Ausgaben, damit neue Treffer und Betriebsberichte dieselben Linkregeln verwenden.
  - [ ] Risiken und Unsicherheiten: Manche Raw-Jobs liefern Detail-URLs mit Trackingparametern; bestehende Canonicalization muss erhalten bleiben; geschlossene Stellen koennen nicht mehr erreichbar sein und duerfen trotzdem als historische offizielle URL angezeigt werden.
  - [ ] Schritte:
    1. Report-Eintraege erweitern: `New-JobAgentReportJobEntry` und Quellen-Issue-Eintraege um Anbieterlink-Objekt oder Linktext/URL aus dem zentralen Vertrag ergaenzen, ohne bestehende Felder zu brechen.
    2. Renderer vereinheitlichen: Markdown- und HTML-Tabellen sollen Stellenlink und Anbieterlink getrennt anzeigen; HTML muss sichere `href`-Attribute und kurze Labels verwenden, Markdown muss direkt klickbare Links erzeugen.
    3. Regressionen absichern: Tests fuer aktive Stellen, neue Stellen, fehlerhafte offizielle Quellen, fehlende Anbieterlinks und HTML-Encoding ergaenzen; vorhandene Daily-Run-Fixtures duerfen keine externen Live-Abrufe ausloesen.
  - [ ] Evidence: Daily-Run-HTML unter `html/jobagent/daily-run-*.html` enthaelt klickbare Stellen- und Anbieterlinks; Markdown-Report enthaelt klickbare Links; Tests decken URL-Encoding, offizielle Quellen und fehlende Links ab.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1`.
  - [ ] Audit: Beispiel-Daily-Run im Browser pruefen: Linklabels eindeutig, offizielle Stellenlinks anklickbar, Anbieterlinks getrennt, Fehlerquellen transparent, keine Layout-Ueberlaeufe bei langen URLs.
  - [ ] Supertest: Erst nach gruenen Funktionstests `.\ci.cmd supertest`; Abschluss nur bei Exit 0.
