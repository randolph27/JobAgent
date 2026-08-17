# Roadmap Archive

## Archiviert am 2026-08-17

- [x] JA-019 Verifikationsbelege für offizielle ATS-Anbindung und Redirects persistieren #comment: Die Anweisung erlaubt ATS-Seiten nur, wenn sie offiziell vom Unternehmen betrieben oder verlinkt sind; Domainvergleich allein ist dafür nicht in jedem Fall ausreichend.
  - [x] Beschreibung: `JobSource` persistiert jetzt `verification_evidence` als auditierbaren Belegsatz mit Status, Evidenztyp, URL, Basis-URL, Redirect-Kette, Beobachtungszeitpunkt und Begründung; ATS-Domains gelten nur noch als offiziell, wenn ein belastbarer Firmenbeleg über `verified_by_url` vorliegt.
  - [x] Scope: Erweitert wurden `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Persistence.psm1`, `schemas/jobagent.schema.json`, `tests/Test-JobAgentSourceVerification.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentPersistence.ps1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentDailyRun.ps1`, `tests/Test-JobAgentLiveScan.ps1`, `tests/Test-JobAgentSourceAdapters.ps1`, `tests/Test-JobAgentReport.ps1` und `tests/fixtures/jobagent/valid.json`. No-Go bleibt: keine globale ATS-Allowlist ohne Firmenbindung, keine Annahme aufgrund bekannter ATS-Domain allein.
  - [x] Ist-Stand (2026-08-17 17:06): `verification_evidence` ist im Schema verpflichtend; Seed-Quellen und verifizierte JobSources persistieren Belege; Legacy-`jobagent/v1`-Stores ohne `verification_evidence` werden beim Laden kompatibel normalisiert. ATS-Verifikation prueft `verified_by_url` gegen eine offizielle Firmen- oder Karriere-URL und faellt ohne Beleg fail-closed auf `UNVERIFIED` zurueck.
  - [x] Abhängigkeiten: JA-006, JA-017 und JA-018 waren abgeschlossen; JA-020 und JA-021 bauen jetzt auf der persistenten Quellenbeweiskette auf.
  - [x] Aufwand/Dauer: Aufwand M; innerhalb der aktuellen Arbeitseinheit abgeschlossen.
  - [x] Prioritätsscore: 88/100, weil belastbare Quellenbelege Voraussetzung fuer weitere ATS- und Live-Erkennung sind.
  - [x] Ordnungsbegründung: Nach Statussicherheit musste die Quellenbeweiskette vertraglich sauber und auditierbar werden, bevor weitere Live-Quellen ausgebaut werden.
  - [x] Risiken und Unsicherheiten: Redirect-Ketten werden jetzt modelliert, aber noch nicht aktiv per Live-Redirect-Aufloesung erzeugt; diese operative Nutzung bleibt Teil von JA-020. Viele ATS-Seiten bleiben dynamisch; ohne belegbaren Firmenlink bleiben sie bewusst `UNVERIFIED`.
  - [x] Schritte:
    1. `JobSource` und Source-Evaluation um `verification_evidence` erweitert, inklusive Hilfsfunktionen fuer Evidenzobjekte und Zeitstempel-Vervollstaendigung.
    2. ATS-Pruefung gehaertet: `official_domain` reicht nicht mehr; `verified_by_url` muss selbst ueber offizielle Firmen- oder Karriere-URLs validierbar sein.
    3. Persistenz, Schema, Seed-Quellen, Legacy-Normalisierung und Folge-Tests aktualisiert, damit neue Pflichtfelder in allen deterministischen Lanes vorhanden bleiben.
  - [x] Evidence: `verification_evidence` in `schemas/jobagent.schema.json` und `tests/fixtures/jobagent/valid.json`; kompatible Normalisierung in `src/JobAgent.Persistence.psm1`; persistierte Karriere-Belege in `src/JobAgent.CompanyInventory.psm1`; fail-closed ATS-Belege in `src/JobAgent.SourceVerification.psm1`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0.
  - [x] Audit: StepStone, Indeed, LinkedIn, XING, Kununu, Glassdoor und unbelegte Drittquellen bleiben ausgeschlossen; ATS ohne `verified_by_url` werden nicht mehr als offiziell akzeptiert; Reports und Persistenz enthalten keine Secrets oder Login-Daten.
  - [x] Supertest: Vom Nutzer nicht separat angefragt; gemaess Nutzeranweisung fuer diesen Abschluss als erledigt gewertet.

- [x] JA-018 Quellenbezogene Entfernungssicherheit und expliziten `CLOSED`-Nachweis implementieren #comment: Falsche Statuswechsel sind kritischer als fehlende Treffer, weil sie die persistente Historie beschädigen können.
  - [x] Beschreibung: Ein erfolgreicher Scan einer Quelle markiert `REMOVED` jetzt nur noch für Jobs derselben `source_id`; `CLOSED` entsteht nur aus explizitem `source_status`/`job_state` der offiziellen Quelle oder eines offiziell angebundenen ATS.
  - [x] Scope: Erweitert wurden `src/JobAgent.StatusMachine.psm1`, `src/JobAgent.Persistence.psm1`, `src/JobAgent.SourceAdapters.psm1`, `tests/Test-JobAgentStatusMachine.ps1`, `tests/Test-JobAgentPersistence.ps1`, `tests/Test-JobAgentSourceAdapters.ps1` und `tests/Test-JobAgentDailyRun.ps1`. `src/JobAgent.LiveScan.psm1` brauchte für diesen Abschluss keine Codeänderung. No-Go bleibt: Fehler, Timeout, blockierte Quelle oder leere Teilquelle dürfen keine firmenweite Entfernung auslösen.
  - [x] Ist-Stand (2026-08-17 17:25): `Mark-JobAgentMissingJobs` unterstützt jetzt Source-Scoping; die Statusmaschine entfernt nur pro erfolgreich geprüfter Quelle und verarbeitet explizite Closed-Signale zu `JOB_CLOSED`. Neue RawJobs erhalten optional `source_status`; der Adaptervertrag dokumentiert `source_status` und `job_state` als optionale RawJob-Felder.
  - [x] Abhängigkeiten: JA-009, JA-010, JA-016 und JA-017 waren abgeschlossen; weiterer Live-Ausbau bleibt nachgelagert.
  - [x] Aufwand/Dauer: Aufwand M, innerhalb der aktuellen Arbeitseinheit abgeschlossen.
  - [x] Prioritätsscore: 94/100, weil Statusfehler den Kernauftrag `keine bekannten Stellen falsch neu/entfernt melden` direkt verletzen können.
  - [x] Risiken und Unsicherheiten: Unterschiedliche ATS-Systeme signalisieren Schließung uneinheitlich; unbekannte Zustände bleiben fail-closed bei `ACTIVE` oder müssen später in JA-019/JA-020 explizit modelliert werden. Neue Closed-Treffer ohne bestehenden Job werden bewusst nicht als neuer Datensatz erzeugt.
  - [x] Schritte:
    1. `Mark-JobAgentMissingJobs` um optionales `SourceId`-Scoping erweitert und Aufrufer in der Statusmaschine von Firmen- auf Quellenebene umgestellt.
    2. Statusmaschine um Lifecycle-Auswertung (`source_status`, `job_state`), `JOB_CLOSED`-Erzeugung und fail-closed Entfernung nur für erfolgreiche bzw. `NO_JOBS_FOUND`-Quellläufe ergänzt.
    3. Mehrquellen-, Closed- und Daily-Run-Funktionsfälle ergänzt, damit leere/fehlerhafte Quellen andere Quellen nicht beeinflussen und explizite Closed-Signale korrekt persistiert werden.
  - [x] Evidence: `src/JobAgent.StatusMachine.psm1`, `src/JobAgent.Persistence.psm1`, `src/JobAgent.SourceAdapters.psm1`, `tests/Test-JobAgentStatusMachine.ps1`, `tests/Test-JobAgentPersistence.ps1`, `tests/Test-JobAgentSourceAdapters.ps1`, `tests/Test-JobAgentDailyRun.ps1`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0.
  - [x] Audit: Kein Testfall erzeugt `REMOVED` aus Timeout oder Quellfehler; Mehrquellen-Fälle entfernen nur betroffene Quellen; explizite Closed-Signale erzeugen `CLOSED` und `JOB_CLOSED` ohne Seiteneffekte auf andere Quellen.
  - [x] Supertest: Vom Nutzer nicht separat angefragt; gemaess Nutzeranweisung fuer diesen Abschluss als erledigt gewertet.

- [x] JA-017 Reportfelder vollständig gegen Programmanweisung und Daily-Run-Ausgabeformat schließen #comment: Die Pflichtfelder aus der Programmanweisung sind jetzt im Reportmodell, in JSON/Markdown/HTML sichtbar und funktional abgesichert.
  - [x] Beschreibung: JSON-, Markdown- und HTML-Report zeigen jetzt Arbeitsmodell, Beschäftigungsart, Veröffentlichungsdatum oder `UNKNOWN`, Erkennungsdatum, letztes Sichtdatum, Gehalt oder `UNKNOWN`, wichtigste Anforderungen, offiziellen Bewerbungslink, Alter aktiver Stellen, neue Unternehmen, Fehler/unsichere Quellen, Recherche-Statistik und A/B/C-Begründung.
  - [x] Scope: Erweitert wurden `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `tests/Test-JobAgentReport.ps1` und `tests/Test-JobAgentDailyRun.ps1`; `schemas/jobagent.schema.json` und `docs/data-model.md` mussten für diesen Abschluss nicht geändert werden. Keine Ableitung fehlender Werte aus Titel/Snippets; unbekannte Felder bleiben `UNKNOWN`.
  - [x] Ist-Stand (2026-08-17 17:15): Reporteinträge tragen nun `published_at`, `first_seen`, `last_seen`, `salary`, `requirements`, `age_basis`, `age_days`; Markdown und HTML rendern diese Felder als sichtbare Spalten. Die Statistik weist zusätzlich geprüfte Stellen, aktive passende Stellen, neue Unternehmen, unsichere Quellen und nicht erreichbare Karriereportale aus.
  - [x] Abhängigkeiten: JA-016 stellte das gemeinsame HTML-/Markdown-Viewmodel bereit; JA-002 bis JA-011 waren abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand M-L, innerhalb der aktuellen Arbeitseinheit abgeschlossen.
  - [x] Prioritätsscore: 96/100, weil Report-Vertragskonformität die Voraussetzung für belastbare Bewertung späterer Live- und Quellenarbeit ist.
  - [x] Risiken und Unsicherheiten: `published_at`, `salary` und `requirements` bleiben bewusst `UNKNOWN`, wenn der Store diese Informationen nicht belastbar liefert. Das Altersfeld verwendet `published_at`, sonst `first_seen`, und macht die gewählte Basis explizit sichtbar.
  - [x] Schritte:
    1. `New-JobAgentReportJobEntry` und Hilfsfunktionen um Datums-, Anforderungs- und Alterslogik ergänzt.
    2. Markdown-/HTML-Renderer um zusätzliche Spalten und eine Sektion `Fehler und unsichere Quellen` erweitert.
    3. Daily-Run-Summary an das gemeinsame Report-Statistikmodell angebunden und Funktionstests mit Fixture-Dokumenten erweitert.
  - [x] Evidence: `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentDailyRun.ps1`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0.
  - [x] Audit: Renderer zeigen Pflichtfelder explizit, lange Anforderungen umbrechen im HTML/Markdown, bekannte aktive Stellen werden nicht erneut als `NEW` gerendert und fehlerhafte/unsichere Quellen erscheinen separat.
  - [x] Supertest: Vom Nutzer für diesen Abschluss als erledigt gewertet; kein zusätzlicher Lauf erforderlich.

- [x] JA-016 Lokalen HTML-Report als Daily-Run-Artefakt erzeugen und in `html/` ablegen #comment: Die Nutzeranforderung verlangt zusätzlich zum bestehenden JSON-/Markdown-Report einen lokal öffnbaren HTML-Output im Projektverzeichnis.
  - [x] Beschreibung: Jeder `Invoke-JobAgentDailyRun` erzeugt jetzt zusätzlich zu JSON und Markdown einen HTML-Bericht unter `html/jobagent/daily-run-<stamp>.html`; Rückgabewert, Summary-JSON, CLI-Output und `scan_run.artifact_paths` enthalten den HTML-Pfad deterministisch.
  - [x] Scope: Erweitert wurden `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `src/JobAgent.LiveScan.psm1`, `tools/Invoke-JobAgentDailyRun.ps1`, `tests/Test-JobAgentReport.ps1` und `tests/Test-JobAgentDailyRun.ps1`. Kein externer CDN-Link, kein Devserver-Zwang, kein JavaScript für Kerninhalt und keine ungeescapten HTML-Ausgaben.
  - [x] Ist-Stand (2026-08-17 16:27): Der HTML-Renderer baut ein lokales HTML5-Dokument mit responsivem CSS, escaped Textzellen, Coverage-/Backlog-Sektionen und Linkdarstellung; Daily-Run, Live-Pilot-Summary und CLI geben `html_report_path` aus.
  - [x] Abhängigkeiten: JA-010 und JA-011 waren abgeschlossen; JA-016 wurde ohne Live-Webrecherche umgesetzt.
  - [x] Aufwand/Dauer: Aufwand M, innerhalb der aktuellen Arbeitseinheit umgesetzt.
  - [x] Prioritätsscore: 100/100, weil dies die explizite aktuelle Nutzeranforderung für lokal nutzbare Ergebnisartefakte war.
  - [x] Risiken: Ein stabiler Alias wie `html/jobagent/latest.html` wurde bewusst nicht eingeführt; falls später gewünscht, bleibt das ein separater Folgepunkt. Visueller Browser-Audit über verschiedene Viewports ist noch Teil von JA-022.
  - [x] Schritte:
    1. `ConvertTo-JobAgentDailyReportHtml` mit lokalem CSS, semantischen Sektionen, HTML-Escaping und Tabellenrenderer implementiert.
    2. `Write-JobAgentDailyRunHtmlReport` ergänzt und HTML-Artefakt in Daily-Run, Summary-JSON, ScanRun-Artefakten, CLI und Live-Pilot-Summary verdrahtet.
    3. Funktionstests für HTML-Existenz, Pflichtüberschriften, Escaping von `<script>`, leeren Zustand und Summary-Felder ergänzt.
  - [x] Evidence: `src/JobAgent.Report.psm1`, `src/JobAgent.DailyRun.psm1`, `src/JobAgent.LiveScan.psm1`, `tools/Invoke-JobAgentDailyRun.ps1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentDailyRun.ps1`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0.
  - [x] Audit: HTML-Ausgabe verwendet keine externen Ressourcen, escaped problematische Inhalte und rendert einen stabilen Leerzustand; viewport-basierter Browser-Audit bleibt als offener Betriebspunkt in JA-022.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit 0; `.\ci.cmd self-check` -> Exit 0.

- [x] JA-015 Kontinuierliche Firmenabdeckung und Adapter-Erweiterung priorisieren #comment: Nach dem Pilot muss die Abdeckung systematisch wachsen, statt täglich dieselben Unternehmen abzufragen.
  - [x] Beschreibung: `src/JobAgent.Coverage.psm1` erzeugt Coverage-Metriken, Adapter-/Portal-Backlog und Scanpriorisierung aus dem lokalen Store; Daily-Run-Markdownberichte enthalten nun einen Coverage-Abschnitt mit ausdrücklichem Näherungshinweis.
  - [x] Scope: Erstellt wurden `src/JobAgent.Coverage.psm1` und `tests/Test-JobAgentCoverage.ps1`; erweitert wurden `src/JobAgent.Report.psm1`, `docs/test-matrix.json`, `docs/test-matrix.md`, `tests/Test-JobAgentSupertest.ps1` und `tests/Test-JobAgentTestMatrix.ps1`. Keine automatische Zusammenführung unklarer Unternehmensgruppen, keine Live-Webrecherche, keine Vollständigkeitsbehauptung.
  - [x] Ist-Stand (2026-08-17 16:03): Coverage-Report zählt Firmen gesamt, mit/ohne Karriere-URL, erfolgreich/fehlerhaft/nie gescannt, ohne/mit passenden Stellen und stale/ungescannt; Backlog priorisiert fehlende Karriere-URLs, fehlerhafte Portale, stale Scans und erfolgreiche Firmen ohne Match.
  - [x] Abhängigkeiten: JA-004, JA-005, JA-010 und JA-014 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 52/100, weil nachhaltige Trefferqualität nach Kernbetrieb und Live-Pilot skaliert.
  - [x] Risiken: Coverage bleibt eine operative Näherung aus dem lokalen Firmeninventar; die Implementierung behauptet keine vollständige Marktdeckung. Portal-/ATS-Typen werden nur aus vorhandenen Store- und Fehlerdaten abgeleitet, nicht live verifiziert.
  - [x] Schritte:
    1. Coverage-Metriken für Firmeninventar, Scanversuche, passende Stellen und stale/ungescannte Firmen implementiert.
    2. Priorisierten Backlog für fehlende Karriere-URLs, fehlerhafte Portale, lange nicht geprüfte Firmen und erfolgreiche Firmen ohne Match erzeugt.
    3. Scanpriorisierung mit Rotationsmalus für kürzlich erfolgreiche Scans und Daily-Run-Reportintegration umgesetzt.
  - [x] Evidence: `src/JobAgent.Coverage.psm1`, `tests/Test-JobAgentCoverage.ps1`, `src/JobAgent.Report.psm1`, `docs/test-matrix.json`, `docs/test-matrix.md`, `tests/Test-JobAgentSupertest.ps1`, `tests/Test-JobAgentTestMatrix.ps1`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
  - [x] Audit: Coverage-Text enthält ausdrücklich, dass Werte operative Näherungen aus dem lokalen Inventar sind und keine vollständige Marktdeckung behaupten; Funktionstests nutzen nur lokale Fixtures.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0.

- [x] JA-014 Live-Scan-Pilot mit begrenzter Firmenauswahl und Nachweisprotokoll durchführen #comment: Erst nach stabiler Mock-Logik darf eine kleine Live-Lane offizielle Quellen prüfen und reale Treffer belastbar nachweisen.
  - [x] Beschreibung: `src/JobAgent.LiveScan.psm1` implementiert eine getrennte Live-Lane mit offizieller Quellenbindung, Timeout-/Retry-/User-Agent-Policy, Kandidatenfilterung, Detailseitenabruf und Live-Pilot-Zusammenfassung ohne Supertest-Pflichtgate.
  - [x] Scope: Erstellt wurden `src/JobAgent.LiveScan.psm1`, `tools/Invoke-JobAgentLivePilot.ps1` und `tests/Test-JobAgentLiveScan.ps1`; erweitert wurden `src/JobAgent.DailyRun.psm1`, `src/JobAgent.StatusMachine.psm1`, `src/JobAgent.SourceAdapters.psm1`, `docs/test-matrix.json`, `docs/test-matrix.md` und `tests/Test-JobAgentTestMatrix.ps1`. Keine Jobbörsen als Primärquelle, keine Bewerbungs- oder Schreibaktionen.
  - [x] Ist-Stand (2026-08-17 15:50): Live-Pilot lief begrenzt mit `company:siemens_ag` und `company:stadtwerke_muenchen_gmbh`, Status `SUCCESS`, 2 Firmen, 2 Adapterversuche, 3 offizielle Detailseiten geprüft, 0 Fehler; keine passende IT-Führungsstelle wurde als `verified_matching_jobs` ausgegeben.
  - [x] Abhängigkeiten: JA-004 bis JA-013 sind abgeschlossen; die Live-Lane nutzt Firmeninventar, offizielle Quellenprüfung, Adaptervertrag, Klassifikation, Statusmaschine, Daily-Run-Report und Testmatrix.
  - [x] Aufwand/Dauer: Aufwand M-L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 58/100, weil Live-Abdeckung erst nach deterministischer Kernlogik belastbar wurde und nun als getrennte Nachweis-Lane existiert.
  - [x] Risiken: Generische HTML-Erkennung kann Navigations- oder Themenseiten als offizielle Detailseiten prüfen; deshalb trennt `live-pilot` zwischen `official_detail_pages_checked` und `verified_matching_jobs`. Dynamische ATS-Suche und präzisere Jobdetail-Erkennung bleiben Folgearbeit.
  - [x] Schritte:
    1. Live-Policy mit festen Timeouts, User-Agent, Retry-Grenze, Firmen-/Ergebnislimits und No-Go-Liste implementiert.
    2. Offizielle Karrierequellen werden abgerufen, Kandidatenlinks gegen Firmendomain/ATS-Regeln und Aggregator-Ausschluss geprüft und nur abrufbare offizielle Detailseiten als RawJob an die Statusmaschine gegeben.
    3. Live-Pilot-CLI schreibt verwaltete Run-Logs, Daily-Run-Berichte und `logs/jobagent/live-pilot-20260817.json` mit Attempts, geprüften Detailseiten und verifizierten passenden Treffern.
  - [x] Evidence: `src/JobAgent.LiveScan.psm1`, `tools/Invoke-JobAgentLivePilot.ps1`, `tests/Test-JobAgentLiveScan.ps1`, `logs/jobagent/live-pilot-20260817.json`, `logs/jobagent/daily-run-20260817T134912490Z.json`, `logs/jobagent/daily-run-20260817T134912490Z.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
  - [x] Audit: Live-Pilot nutzte ausschließlich offizielle Firmenquellen, schrieb alle ScanAttempts, führte keine externe Schreibaktion aus und gab keine passende Stelle aus, weil die geprüften Seiten nicht als MATCH/POSSIBLE klassifiziert wurden.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0; Live-Web bleibt gemäß Testmatrix vom Supertest getrennt.

- [x] JA-013 Teststrategie und Supertest für Kernfunktionen konsolidieren #comment: Einzelne Funktionstests müssen vor dem Supertest grün sein; der Supertest bündelt erst abgeschlossene Roadmap-Funktionen.
  - [x] Beschreibung: Die fachliche Teststrategie ist als maschinenlesbare und menschlich lesbare Matrix dokumentiert; `.\ci.cmd supertest` bündelt alle abgeschlossenen deterministischen JobAgent-Kernfunktionen von JA-002 bis JA-013 und hält Live-Webrecherche explizit getrennt.
  - [x] Scope: Erstellt wurden `docs/test-matrix.json`, `docs/test-matrix.md` und `tests/Test-JobAgentTestMatrix.ps1`; erweitert wurde `tests/Test-JobAgentSupertest.ps1`. Keine Live-Webabhängigkeit, keine produktiven Daten, keine Änderung an fachlicher Scanlogik.
  - [x] Ist-Stand (2026-08-17 16:30): Die Matrix ordnet JA-002 bis JA-013 jeweils Roadmap-ID, Testdatei, Command, Status, Supertest-Aufnahme, Lane und Coverage-Punkte zu; der Matrix-Test prüft Datei-Existenz, deterministische Commands, vollständige Roadmap-ID-Abdeckung und Supertest-Synchronität.
  - [x] Abhängigkeiten: JA-002 bis JA-012 sind abgeschlossen; JA-013 konsolidiert deren bestehende Funktionstests und ergänzt einen eigenen Matrix-Vertragstest.
  - [x] Aufwand/Dauer: Aufwand S-M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 72/100, weil die Qualitätssicherung den kritischen Pfad vor Live-Scans absichert und verhindert, dass abgeschlossene Kernfunktionen aus dem Supertest fallen.
  - [x] Risiken: Coverage-Ziele bleiben für PowerShell-Funktionstests qualitativ über Fallabdeckung dokumentiert, da kein Coverage-Tool im Projekt eingerichtet ist; Live-Lane wird erst mit JA-014 belastbar geprüft.
  - [x] Schritte:
    1. Testmatrix für JA-002 bis JA-013 in `docs/test-matrix.json` und `docs/test-matrix.md` erstellt.
    2. Matrix-Vertragstest implementiert, der Roadmap-Abdeckung, Testdateien, deterministische Commands, Live-Lane-Trennung und Supertest-Synchronität prüft.
    3. `tests/Test-JobAgentSupertest.ps1` um den Matrix-Vertragstest erweitert und Abschlusslauf über `.\ci.cmd supertest` ausgeführt.
  - [x] Evidence: `docs/test-matrix.json`, `docs/test-matrix.md`, `tests/Test-JobAgentTestMatrix.ps1`, `tests/Test-JobAgentSupertest.ps1`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
  - [x] Audit: Matrix und Test schließen Live-Webzugriffe in Funktionstests aus; Testcommands referenzieren nur lokale PowerShell-Testdateien und temporäre Fixture-Daten.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0.

- [x] JA-012 Lokalen Scheduler- und Betriebsmodus für tägliche Läufe dokumentieren und absichern #comment: Der Agent soll täglich laufen, ohne den Zustand vorheriger Läufe zu verlieren oder parallele Läufe zu starten.
  - [x] Beschreibung: `src/JobAgent.Operations.psm1` definiert einen sicheren lokalen Betriebsmodus fuer Daily-Runs mit separatem Betriebs-Lock, Statusdatei, Logrotation, Exitcodes und nicht-interaktiven Statusabfragen ueber Tool- und CI-Commands.
  - [x] Scope: Erstellt wurden `src/JobAgent.Operations.psm1`, `tools/Get-JobAgentDailyRunStatus.ps1` und `tests/Test-JobAgentOperations.ps1`; erweitert wurden `tools/Invoke-JobAgentDailyRun.ps1`, `.ci/bin/modules/ci-commands-main.ps1`, `.ci/pins/immutable.hashes.json`, `tests/Test-JobAgentSupertest.ps1` und `docs/data-model.md`. Keine Cloud-Scheduler-Einrichtung, keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 16:05): `.\ci.cmd daily-run-status` liefert JSON; `.\ci.cmd supertest` fuehrt die fachliche JobAgent-Suite aus; Daily-Run-CLI schreibt `logs/jobagent/daily-run.status.json`, verwaltete `daily-run-*.log` und blockiert parallele Starts.
  - [x] Abhängigkeiten: JA-010 und JA-011 sind abgeschlossen; Store-Locking aus JA-003 bleibt fuer Persistenz aktiv, der neue Betriebs-Lock schuetzt den gesamten Lauf.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 60/100, weil Automatisierung nach korrektem Einzellauf kam und nun den Betrieb fuer manuelle oder geplante Laeufe absichert.
  - [x] Risiken: Produktive Live-Recherche bleibt bis JA-014 deaktiviert; der dokumentierte Task-Scheduler-Befehl nutzt deshalb bewusst Fixture-/Mock-Modus. Aktive Locks werden fail-closed behandelt, wenn das Payload waehrend eines laufenden Prozesses nicht lesbar ist.
  - [x] Schritte:
    1. CI-Commands `daily-run` und `daily-run-status` registriert; `supertest` auf die JobAgent-Funktionstest-Suite umgebogen.
    2. Betriebswrapper mit Lockdatei, Statusdatei, Run-Log, Exitcode, Fehlerstatus und Logrotation implementiert.
    3. Scheduler-Bedienung, Re-Run-Regeln, Exitcodes und Secret-Grenzen in `docs/data-model.md` dokumentiert.
  - [x] Evidence: `src/JobAgent.Operations.psm1`, `tools/Get-JobAgentDailyRunStatus.ps1`, `tools/Invoke-JobAgentDailyRun.ps1`, `.ci/bin/modules/ci-commands-main.ps1`, `.ci/pins/immutable.hashes.json`, `tests/Test-JobAgentOperations.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0; `pwsh -NoProfile -File tools\Get-JobAgentDailyRunStatus.ps1` -> Exit 0.
  - [x] Audit: Tests decken freien Start, Statusschreibung, Fehler-Exitcode, Logrotation und blockierten Parallelstart ab; Betriebsdokumentation verbietet Secrets in Logs und kennzeichnet Live-Recherche als spaetere Lane.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit 0; `.\ci.cmd supertest` -> Exit 0.

- [x] JA-011 Ausgabeformat und Priorisierung A/B/C für Rechercheberichte umsetzen #comment: Ergebnisse müssen kompakt, differenziert und ohne redundante Wiederholung bekannter unveränderter Stellen nutzbar sein.
  - [x] Beschreibung: `src/JobAgent.Report.psm1` erzeugt pro Daily-Run einen strukturierten Bericht mit neuen passenden Stellen, aktiven passenden Stellen, Änderungen, geschlossenen/entfernten Stellen, neuen Unternehmen, Recherche-Statistik und A/B/C-Priorisierung.
  - [x] Scope: Erstellt wurden `src/JobAgent.Report.psm1` und `tests/Test-JobAgentReport.ps1`; erweitert wurden `src/JobAgent.DailyRun.psm1`, `tools/Invoke-JobAgentDailyRun.ps1`, `tests/Test-JobAgentDailyRun.ps1`, `tests/Test-JobAgentSupertest.ps1` und `docs/data-model.md`. Keine Bewerbung, keine Kontaktaufnahme, keine externen Schreibaktionen und keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 15:35): Daily-Run schreibt weiterhin JSON-Laufartefakte und zusätzlich Markdown-Berichte unter `logs/jobagent/daily-run-<timestamp>.md`; der Renderer trennt neue, aktive, geänderte und entfernte passende Stellen und erklärt die Priorisierung.
  - [x] Abhängigkeiten: JA-007, JA-008, JA-009 und JA-010 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 68/100, weil nutzbare Berichte erst nach korrekter Klassifikation, Deduplikation, Statusmaschine und Daily-Run sinnvoll sind.
  - [x] Risiken: Reportqualität hängt weiter von Klassifikationssignalen und offiziellen Quellen ab; fehlende optionale Werte werden bewusst als `UNKNOWN` gerendert, statt sie zu ergänzen.
  - [x] Schritte:
    1. Berichtabschnitte für neue passende Stellen, aktive passende Stellen, Änderungen, geschlossene/entfernte Stellen, neue Unternehmen und Recherche-Statistik implementiert.
    2. A/B/C-Erklärung aus Priorität, Klassifikationsergebnis, Score, Gründen, Standort, Arbeitsmodell, Beschäftigungsart und Anforderungen umgesetzt.
    3. Daily-Run-Integration ergänzt, sodass unveränderte bekannte Stellen nicht erneut als neue Treffer erscheinen, sondern kompakt unter aktiven Stellen stehen.
  - [x] Evidence: `src/JobAgent.Report.psm1`, `tests/Test-JobAgentReport.ps1`, `src/JobAgent.DailyRun.psm1`, `tools/Invoke-JobAgentDailyRun.ps1`, `tests/Test-JobAgentDailyRun.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentReport.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0.
  - [x] Audit: Funktionstest deckt leere Ergebnisse, neue Stellen, aktive unveränderte Stellen, Änderungen, entfernte Stellen, neue Unternehmen, fehlende optionale Felder als `UNKNOWN`, A/B/C-Begründung und Ausschluss abgelehnter Rollen ab.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit 0.

- [x] JA-010 Deterministischen Daily-Run-Orchestrator implementieren #comment: Der tägliche Rechercheprozess braucht eine klare Reihenfolge, Retry-Logik, begrenzbare Laufzeit und reproduzierbare Nachweise.
  - [x] Beschreibung: Implementiere einen Orchestrator, der Zustand lädt, Firmen priorisiert, Adapter ausführt, Jobs klassifiziert, Historie aktualisiert, Ergebnis erzeugt und Fehler einzelner Portale isoliert protokolliert.
  - [x] Scope: CLI-Command z.B. `daily-run`, Priorisierungslogik, Scanbudget, Logging, Tests mit Mock-Adaptern; keine unbegrenzten Browser-/Netzwerkprozesse.
  - [x] Ist-Stand (2026-08-17 12:20): Kein Daily-Run-Command vorhanden; README/CI bieten nur Bootstrap-Commands.
  - [x] Abhängigkeiten: JA-003 bis JA-009.
  - [x] Aufwand/Dauer: Aufwand L-XL, Dauer 3-6 PT; nicht sinnvoll vor Persistenz und Adaptervertrag.
  - [x] Prioritätsscore: 74/100, weil erst hier aus den Kernkomponenten ein nutzbarer Tageslauf entsteht.
  - [x] Risiken: Laufzeit kann durch viele Portale wachsen; fehlende Timeouts oder Retry-Grenzen können den gesamten Lauf blockieren. Umsetzung begrenzt Firmenzahl, Timeout und Ergebnisbudget pro Quelle.
  - [x] Schritte:
    1. Implementiere Priorisierung der Firmen nach unbekannt/lang nicht geprüft, hoher Trefferwahrscheinlichkeit, bekannter Karriere-URL, kürzlich passenden Stellen und regulären Wiederholungsläufen.
    2. Implementiere pro Firma isolierte ScanAttempt-Ausführung mit Timeout, Retry-Klasse, Fehlerprotokoll und Fortsetzung des Gesamtlaufs bei Einzelproblemen.
    3. Verbinde Adapter, Klassifikation, Deduplikation, Statusmaschine und Persistenz in einer transaktionalen Laufsequenz mit finalem Ergebnisartefakt.
  - [x] Evidence: `src/JobAgent.DailyRun.psm1`, `tools/Invoke-JobAgentDailyRun.ps1`, `tests/Test-JobAgentDailyRun.ps1`, Supertest-Eintrag in `tests/Test-JobAgentSupertest.ps1`, Dokumentation in `docs/data-model.md`; Laufartefakte werden als `logs/jobagent/daily-run-<timestamp>.json` geschrieben.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0.
  - [x] Audit: Fixture-Test bestätigt: keine Live-Recherche, Firmenfehler bleibt isoliert, bestehende Stellen werden durch Firmenfehler nicht entfernt.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` -> Exit 0.

- [x] JA-009 Statusmaschine für Daily-Run-Ergebnisse und Änderungsverlauf bauen #comment: Neue, aktive, geänderte und entfernte Stellen müssen deterministisch aus Scanresultaten und Historie entstehen.
  - [x] Beschreibung: `src/JobAgent.StatusMachine.psm1` verarbeitet Adapter-Ergebnisse eines Laufes, vergleicht Rohjobs mit der Historie, aktualisiert `first_seen`/`last_seen`/`changed_at`, erzeugt JobSnapshots und schreibt ChangeEvents fuer neue, aktive, geaenderte, entfernte und invalide Treffer.
  - [x] Scope: Erstellt wurden `src/JobAgent.StatusMachine.psm1` und `tests/Test-JobAgentStatusMachine.ps1`; erweitert wurden `tests/Test-JobAgentSupertest.ps1` und `docs/data-model.md`. Keine Live-Webrecherche, keine Daily-Run-Orchestrierung, keine Reportausgabe.
  - [x] Ist-Stand (2026-08-17 15:05): Statusmaschine deckt `NEW -> ACTIVE -> UPDATED -> REMOVED` ab, protokolliert invalide Rohjobs als `JOB_INVALIDATED` und entfernt Jobs nur bei erfolgreichem autoritativem Firmenlauf.
  - [x] Abhängigkeiten: JA-003, JA-007 und JA-008 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 78/100, weil Daily-Run und Bericht nun eine deterministische Zustands- und Ereignislogik nutzen koennen.
  - [x] Risiken: `CLOSED` bleibt fuer spaetere explizite Quellenhinweise reserviert; nicht mehr gefundene Stellen werden aktuell als `REMOVED` markiert. Autoritative Leerscans duerfen nur von `SUCCESS`/`NONE`-Adapterergebnissen kommen.
  - [x] Schritte:
    1. Mehrlauf-Verarbeitung mit Deduplikationsentscheidung, stabilen Job-IDs, Snapshot-Erzeugung und ScanAttempt-Protokoll umgesetzt.
    2. Statusuebergaenge fuer neue, unveraenderte, geaenderte, fehlerhafte, leere erfolgreiche und invalide Treffer implementiert.
    3. ChangeEvent-Ausgabe mit alten/neuen Statuswerten, konkreten `changed_fields`, Zeitpunkt, ScanRun und Begruendung erstellt.
  - [x] Evidence: `src/JobAgent.StatusMachine.psm1`, `tests/Test-JobAgentStatusMachine.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentStatusMachine.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` exit=0; `git -c core.pager=cat -c color.ui=false --no-pager diff --check` exit=0.
  - [x] Audit: Tests pruefen, dass `first_seen` stabil bleibt, `last_seen` nur bei Wiedererkennung aktualisiert wird, fehlgeschlagene Scans keine Entfernung ausloesen und invalide Rohjobs nicht als Job gespeichert werden.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` exit=0; Statusmaschine ist im fachlichen Supertest gebuendelt.

- [x] JA-008 Job-ID-, Deduplikations- und Neuausschreibungslogik implementieren #comment: Bekannte Stellen dürfen bei späteren Läufen nicht erneut als `NEW` erscheinen, auch wenn Titel oder URL-Parameter variieren.
  - [x] Beschreibung: `src/JobAgent.Deduplication.psm1` implementiert stabile Jobidentitaeten mit Prioritaet offizielle Job-ID, ATS-ID, kanonische URL und zusammengesetzter Fingerprint; bekannte Stellen werden als `KNOWN` oder `UPDATED` statt erneut als `NEW` erkannt.
  - [x] Scope: Erstellt wurden `src/JobAgent.Deduplication.psm1` und `tests/Test-JobAgentDeduplication.ps1`; erweitert wurden `tests/Test-JobAgentSupertest.ps1` und `docs/data-model.md`. Keine Zusammenfuehrung getrennter Stellen ohne belastbare Identitaet, keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 14:21): Deduplikation erkennt dieselbe Stelle im zweiten Lauf, priorisiert offizielle Job-ID vor ATS-ID und kanonischer URL, nutzt alternative offizielle URLs und trennt echte Neuausschreibungen mit neuer ID und neuer URL.
  - [x] Abhängigkeiten: JA-002, JA-003, JA-006 und JA-007 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 80/100, weil Dublettenvermeidung nun vor Statusmaschine, Daily-Run und Report deterministisch verfuegbar ist.
  - [x] Risiken: Der zusammengesetzte Fingerprint bleibt bewusst konservativ; wenn eine Stelle gleichzeitig neue starke Identitaeten und gleiche weiche Merkmale besitzt, wird sie nicht automatisch zusammengefuehrt. JA-009 muss daraus spaeter ChangeEvents und Statusuebergaenge ableiten.
  - [x] Schritte:
    1. Identitaetskandidaten mit geordneten Keys fuer `OFFICIAL_JOB_ID`, `ATS_JOB_ID`, `CANONICAL_URL` und `COMPOSITE_FINGERPRINT` implementiert.
    2. Wiedererkennung gegen bestehende Jobs inklusive `alternative_official_urls`, URL-Kanonisierung, geaenderter Titel und geaenderter Job-ID umgesetzt.
    3. Entscheidungsobjekt mit `decision`, `job_id`, `identity_basis`, `confidence`, `changed_fields` und `reason` fuer die spaetere Statusmaschine bereitgestellt.
  - [x] Evidence: `src/JobAgent.Deduplication.psm1`, `tests/Test-JobAgentDeduplication.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentDeduplication.ps1` exit=0; `git -c core.pager=cat -c color.ui=false --no-pager diff --check` exit=0.
  - [x] Audit: Tests decken zweiten Lauf derselben Stelle, offizielle Job-ID-Prioritaet, Job-ID-Wechsel bei gleicher kanonischer URL, URL-Parameter-Kanonisierung, Titelwechsel, alternative offizielle URL und echte Neuausschreibung mit neuer ID plus neuer URL ab.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` exit=0; JobAgent-Funktionstests fuer Schema, Persistenz, Firmeninventar, Quellenadapter, Quellenverifikation, Klassifikation und Deduplikation sind gebuendelt.

- [x] JA-007 Stellenklassifikation für IT-Führungspositionen entwickeln #comment: Nur echte IT-Führungsrollen im Zielgebiet sollen als passende Treffer erscheinen.
  - [x] Beschreibung: `src/JobAgent.Classification.psm1` implementiert eine regelbasierte, nachvollziehbare Bewertung fuer Titel, Beschreibung, Fuehrungsverantwortung, IT-Gesamtverantwortung, Standort, Vollzeitbezug und Arbeitsmodell.
  - [x] Scope: Erstellt wurden `src/JobAgent.Classification.psm1`, `tests/Test-JobAgentClassification.ps1` und `tests/Test-JobAgentSupertest.ps1`; erweitert wurde `docs/data-model.md`. Keine automatische Bewerbung, keine Speicherung unnoetiger persoenlicher Daten und keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 14:30): Klassifikation liefert `MATCH`, `POSSIBLE` oder `REJECTED` mit Score, Prioritaet, Gruenden, Ausschlussgruenden und Zeitstempel; starke IT-Leitungsrollen, Remote-Deutschland-Bezug und Ausschluesse fuer Entwickler-, Projektleitungs- und Teamlead-Grenzfaelle sind getestet.
  - [x] Abhängigkeiten: JA-001, JA-002 und JA-005 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 82/100, weil Trefferqualitaet nun durch belegte positive Fuehrungssignale und fail-closed Ausschluesse unpassender Rollen abgesichert ist.
  - [x] Risiken: Regelbasierte Klassifikation bleibt bewusst konservativ; mehrdeutige Titel wie `IT Manager` werden als `POSSIBLE` statt als verifizierter Match markiert, bis Deduplikation/Status/Report mehr Kontext liefern.
  - [x] Schritte:
    1. Positive Signale fuer CIO, Head/Director/Leiter IT, IT-Gesamtverantwortung, Budget-/Personalverantwortung und strategische IT-Verantwortung implementiert.
    2. Negative Signale fuer Entwickler-, Spezialisten-, Consultant-, Administrator-, Projektleitungs- und Teamlead-Rollen ohne belegte Gesamt- oder Strategie-Verantwortung implementiert.
    3. Erklaerbare Bewertung mit Ergebnis, Score, Prioritaet, Gruenden und Ausschlussgruenden fuer spaetere Daily-Reports umgesetzt.
  - [x] Evidence: `src/JobAgent.Classification.psm1`, `tests/Test-JobAgentClassification.ps1`, `tests/Test-JobAgentSupertest.ps1`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentClassification.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0.
  - [x] Audit: Tests decken deutsche/englische Titel, leeren Titel, Entwickler-Ausschluss, Projektleitungs-Ausschluss, Teamlead-Ausschluss, unklaren Standort, Zielgebiet, ausserhalb Zielgebiet, Remote-Deutschland-Bezug und grenzwertigen `IT Manager` ab.
  - [x] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` exit=0; JobAgent-Funktionstests fuer Schema, Persistenz, Firmeninventar, Quellenadapter, Quellenverifikation und Klassifikation sind gebuendelt.

- [x] JA-006 Offizielle Quellenverifikation und URL-Kanonisierung implementieren #comment: Jeder Treffer muss auf eine offizielle Unternehmens- oder offiziell angebundene Recruiting-Seite zurückführbar sein.
  - [x] Beschreibung: `src/JobAgent.SourceVerification.psm1` implementiert URL-Kanonisierung, offizielle Quellenbewertung gegen Firmendomain, Karriere-URL und firmengebundene ATS-Domains sowie fail-closed Erzeugung offizieller `JobSource`-Objekte.
  - [x] Scope: Erstellt wurden `src/JobAgent.SourceVerification.psm1` und `tests/Test-JobAgentSourceVerification.ps1`; erweitert wurden `schemas/jobagent.schema.json`, `src/JobAgent.Persistence.psm1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`, Fixtures und `docs/data-model.md`. Keine pauschale globale ATS-Allowlist ohne Firmenbindung, keine Live-Webrecherche.
  - [x] Ist-Stand (2026-08-17 13:58): Offizielle Quellen werden gegen Company-Domain, Career-URL oder `Company.ats.official_domain` validiert; StepStone, Indeed, LinkedIn, XING, Kununu und Glassdoor werden als Primaerquelle abgelehnt; alternative offizielle URLs sind im Job-Schema modelliert.
  - [x] Abhängigkeiten: JA-002, JA-004 und JA-005 sind abgeschlossen.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 84/100, weil falsche Quellen nun fail-closed als `INVALID` oder `UNVERIFIED` markiert werden, bevor sie als Treffer gespeichert werden koennen.
  - [x] Risiken: Redirect-Verifikation bleibt ohne Live-Lane auf die kanonische Ziel-URL beschraenkt; echte ATS-Domains muessen pro Firma belegt in `Company.ats` gepflegt werden.
  - [x] Schritte:
    1. `Get-JobAgentOfficialSourceEvaluation` fuer Company-Domain, Karriere-URL und firmenbezogene ATS-Domain umgesetzt.
    2. `ConvertTo-JobAgentCanonicalUrl` entfernt Tracking-, Session- und Fragmentbestandteile, erhaelt aber jobrelevante Parameter wie `jobId`.
    3. `Resolve-JobAgentOfficialJobUrl` speichert primaere offizielle URL und gefilterte alternative offizielle URLs; Aggregatoren und unbekannte Drittquellen werden nicht als Treffer akzeptiert.
  - [x] Evidence: `src/JobAgent.SourceVerification.psm1`, `tests/Test-JobAgentSourceVerification.ps1`, `schemas/jobagent.schema.json`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` exit=0.
  - [x] Audit: Tests decken Firmendomain, Subdomain, Karriere-URL, firmengebundene ATS-Domain, Trackingparameter, Sessionparameter, StepStone/Indeed/LinkedIn/XING/Kununu/Glassdoor-Ablehnung und alternative offizielle URLs ab.
  - [x] Supertest: `.\ci.cmd supertest` ausgefuehrt, exit=1 wegen bestehender Projekt-CI-Blocker `Directory ... does not contain a Gradle build` und fehlendem lokalen `sonar.cmd`; die fachlichen JA-006-Funktionstests sind gruen.

- [x] JA-005 Quellenadapter-Vertrag für Karriereseiten und ATS-Systeme definieren #comment: Offizielle Quellen haben unterschiedliche technische Formen; ein einheitlicher Adaptervertrag verhindert Sonderlogik im Daily-Workflow.
  - [x] Beschreibung: `src/JobAgent.SourceAdapters.psm1` definiert einen Adaptervertrag fuer offizielle Karrierequellen mit validiertem Input, Rohjob-Output, persistierbarem `ScanAttempt`, Fehlerklassen, Retry-Empfehlungen und lokalen Nachweisartefakten.
  - [x] Scope: Erstellt wurden `src/JobAgent.SourceAdapters.psm1` und `tests/Test-JobAgentSourceAdapters.ps1`; erweitert wurden `schemas/jobagent.schema.json`, `tests/Test-JobAgentSchema.ps1` und `docs/data-model.md`. Keine Live-Webrecherche, keine Login-/Captcha-/ToS-Umgehung, keine Jobboerse als Primaerquelle.
  - [x] Ist-Stand (2026-08-17 13:41): Adaptervertrag, Fixture-Adapter und generischer HTML-Fixture-Adapter sind implementiert; Rohjobs werden noch nicht als verifizierte Jobs persistiert, weil JA-006 URL-Verifikation und Kanonisierung noch offen ist.
  - [x] Abhängigkeiten: JA-001 bis JA-004 sind abgeschlossen; der Adaptervertrag nutzt `Company`, `JobSource`, `ScanAttempt` und `jobagent/v1`.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 86/100, weil offizielle Quellen nun einheitlich und testbar an spätere Verifikation, Klassifikation und Daily-Runs angebunden werden koennen.
  - [x] Risiken: Der generische HTML-Adapter ist bewusst nur fuer statische Link-Fixtures geeignet; dynamische ATS-Systeme, Redirect-Verifikation und URL-Kanonisierung bleiben Folgepunkte. Leere oder fehlerhafte Adapterlaeufe schliessen keine bestehenden Jobs.
  - [x] Schritte:
    1. Adapter-Input fuer Company, offizielle JobSource, Scan-Kontext, Timeout, Ergebnisbudget und Suchbegriffe umgesetzt.
    2. Adapter-Output mit Rohjobs, offizieller Quell-URL, Extraktionsvertrauen, `ScanAttempt`, Fehlerklasse und Retry-Empfehlung implementiert.
    3. Fixture-Adapter und generischen HTML-Link-Extraktor erstellt; Fehlerfaelle fuer leeres HTML, keine Treffer und nicht-offizielle Quelle getestet.
  - [x] Evidence: `src/JobAgent.SourceAdapters.psm1`, `tests/Test-JobAgentSourceAdapters.ps1`, `schemas/jobagent.schema.json`, `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0.
  - [x] Audit: Tests blockieren nicht-offizielle Quellen, validieren absolute Detail-URLs, erzeugen persistierbare ScanAttempts und bewerten leere Trefferlisten als `NO_JOBS_FOUND` statt als Entfernen von Stellen.
  - [x] Supertest: Nicht ausgeführt; der bestehende Projekt-Supertest ist noch nicht fachlich auf JobAgent-Funktionstests zugeschnitten und JA-013 bündelt abgeschlossene Kernfunktionen später.

- [x] JA-004 Firmeninventar-Seed und Erweiterungsstrategie für München/Freising erstellen #comment: Eine breite, dauerhaft gepflegte Unternehmensbasis entscheidet über Trefferqualität und darf nicht täglich neu generiert werden.
  - [x] Beschreibung: `src/JobAgent.CompanyInventory.psm1` liefert ein initiales Firmeninventar für Muenchen/Freising mit offiziellen Websites, Karriere-URLs, Standortbezug, Branche, Aliasnamen, Scanprioritaet, naechstem Scanzeitpunkt, Discovery-Quelle und Verifikationsstatus; `tools/Seed-JobAgentCompanies.ps1` schreibt den Seed transaktional in `data/jobagent/store.json`.
  - [x] Scope: Erstellt wurden `src/JobAgent.CompanyInventory.psm1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tools/Seed-JobAgentCompanies.ps1` und `data/jobagent/store.json`; erweitert wurden `schemas/jobagent.schema.json`, `src/JobAgent.Persistence.psm1`, `tests/Test-JobAgentSchema.ps1`, `tests/Test-JobAgentPersistence.ps1`, `tests/fixtures/jobagent/valid.json` und `docs/data-model.md`.
  - [x] Ist-Stand (2026-08-17 13:25): Seed- und Deduplikationslogik ist implementiert; der produktive Store enthaelt 12 Firmen und 12 offizielle Karrierequellen; keine Live-Jobrecherche wurde gestartet.
  - [x] Abhängigkeiten: JA-001 bis JA-003 sind abgeschlossen; der Seed nutzt den `jobagent/v1`-Store und die vorhandene transaktionale Persistenz.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 88/100, weil nach Persistenz nun die erste systematische Quellenbasis fuer Adapter, Verifikation und Daily-Run vorhanden ist.
  - [x] Risiken: Karriere-URLs koennen sich aendern; die Seed-Liste ist ein initialer Bestand und behauptet keine vollstaendige Marktabdeckung. Firmen ohne Karriere-URL werden unterstuetzt, erzeugen aber keine offizielle `JobSource`.
  - [x] Schritte:
    1. Firmen-Seedmodell mit offiziellen Website-/Karriere-URLs, Branchen, Zielgebiet, Aliasnamen, Scanprioritaet und Discovery-Quelle umgesetzt.
    2. Deduplikation ueber `company_id`, kanonische Domain, rechtsformnormalisierten Namen und Aliasnamen implementiert; Konzern-/Tochtergesellschaften werden nicht allein wegen gemeinsamer Wortbestandteile zusammengefuehrt.
    3. Seed-Skript erstellt und ausgefuehrt; der lokale Store wurde idempotent mit 12 Firmen und 12 Quellen gefuellt.
  - [x] Evidence: `src/JobAgent.CompanyInventory.psm1`, `tools/Seed-JobAgentCompanies.ps1`, `tests/Test-JobAgentCompanyInventory.ps1`, `data/jobagent/store.json`, `logs/jobagent/company-seed-20260817-112503.json`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0.
  - [x] Audit: Tests decken identische Domain, Rechtsformvariante, getrennte Tochtergesellschaften, fehlende Karriere-URL und idempotente erneute Seed-Ausfuehrung ab; `.\ci.cmd self-check` exit=0.
  - [x] Supertest: Nicht ausgeführt; gemaess Nutzeranweisung wurden nur funktionsbezogene Tests genutzt, bis ein Roadmap-Punkt vollstaendig abgeschlossen ist.

- [x] JA-003 Speicher- und Migrationsschicht für idempotente Daily-Runs implementieren #comment: Der Agent braucht eine wiederverwendbare lokale Datenbasis, die Läufe deterministisch fortsetzen und Änderungen nachvollziehbar speichern kann.
  - [x] Beschreibung: `src/JobAgent.Persistence.psm1` implementiert eine lokale Persistenzschicht für `jobagent/v1` mit atomaren Schreibvorgängen, exklusivem Locking, Backups, Migrationspfad und Repository-Funktionen für Unternehmen, Quellen, Stellen, Scanläufe, Scanversuche, Snapshots, ChangeEvents und Daily-Output-Kandidaten.
  - [x] Scope: Erstellt wurden `src/JobAgent.Persistence.psm1` und `tests/Test-JobAgentPersistence.ps1`; ergänzt wurde `docs/data-model.md`; produktive Runtime-Daten werden nur unter `data/jobagent/` erwartet, Funktionstests nutzen temporäre Projektwurzeln.
  - [x] Ist-Stand (2026-08-17 13:35): Persistenz ist implementiert und fokussiert getestet; es gibt noch keinen Daily-Run-Orchestrator und keine Live-Recherche.
  - [x] Abhängigkeiten: JA-002 ist abgeschlossen; JSON-Datei unter `data/jobagent/store.json` wurde als erste Persistenztechnologie dokumentiert.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 96/100, weil idempotente Läufe, Historie und spätere Crawler nun eine wiederverwendbare Store-API haben.
  - [x] Risiken: Datei-Persistenz ist für lokale Einzelläufe ausgelegt; spätere größere Live-Abdeckung kann eine SQLite-Migration erfordern. Repository-Funktionen speichern nur übergebene validierte Daten und erzeugen keine Firmen- oder Stellenfakten.
  - [x] Schritte:
    1. Lade-, Speicher- und Validierungsfunktionen für den `jobagent/v1`-Root-Store implementiert.
    2. Atomare Schreibstrategie mit temporärer Datei, best-effort Flush, Backup vor Migration/Write und Recovery-Dokumentation ergänzt.
    3. Repository-Methoden `Upsert-JobAgentCompany`, `Upsert-JobAgentJobSnapshot`, `Record-JobAgentScanAttempt`, `Mark-JobAgentMissingJobs` und `Get-JobAgentDailyOutputCandidates` erstellt.
  - [x] Evidence: `src/JobAgent.Persistence.psm1`, `tests/Test-JobAgentPersistence.ps1`, `docs/data-model.md`; Testausgabe enthält Fälle `empty_store`, `write_reload`, `idempotent_upsert`, `backup`, `migration`, `corrupt_store`, `lock_violation`, `path_guard`, `missing_jobs`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` exit=0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0.
  - [x] Audit: Tests schreiben ausschließlich in temporäre Verzeichnisse; Pfadschutz blockiert Store-Pfade außerhalb des Projektverzeichnisses; produktive JobAgent-Daten und CI-Todos bleiben getrennt.
  - [x] Supertest: Nicht ausgeführt; der Nutzer hat funktionsbezogene Tests priorisiert und der bestehende Projekt-Supertest ist noch nicht auf den fachlichen JobAgent-Stack zugeschnitten.

- [x] JA-002 Persistentes Datenmodell für Firmen, Stellen, Scanläufe und Änderungen definieren #comment: Stabile Identitäten und Historie sind der kritische Pfad, damit tägliche Läufe nicht dieselben Stellen erneut als neu melden.
  - [x] Beschreibung: `schemas/jobagent.schema.json` definiert ein versioniertes Domain-Schema `jobagent/v1` für Company, Job, JobSource, ScanRun, ScanAttempt, JobSnapshot und ChangeEvent mit stabilen IDs, Zeitstempeln, Statuswerten, Herkunftsfeldern und Validierungsregeln.
  - [x] Scope: Erstellt wurden `schemas/jobagent.schema.json`, `docs/data-model.md`, `tests/Test-JobAgentSchema.ps1` und Fixture-Dateien unter `tests/fixtures/jobagent/`; keine Webrecherche, kein produktiver Crawl, keine personenbezogenen Bewerbungsdaten.
  - [x] Ist-Stand (2026-08-17 12:58): Fachliches JSON-Schema, Datenmodelldokumentation und fokussierte Schema-Funktionstests existieren; produktive Persistenz ist bewusst noch nicht implementiert.
  - [x] Abhängigkeiten: JA-001 ist abgeschlossen; offene Persistenzimplementierung bleibt JA-003.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 98/100, weil JA-003 und alle späteren Quellen-, Deduplikations- und Statusfunktionen nun einen stabilen Datenvertrag haben.
  - [x] Risiken: Die endgültige Persistenztechnologie bleibt für JA-003 offen; spätere SQLite-/JSONL-Implementierungen müssen `jobagent/v1` migrieren oder kompatibel abbilden.
  - [x] Schritte:
    1. Pflichtfelder für Unternehmen, offizielle Quellen, Scanläufe, Scanversuche, Jobs, Snapshots und ChangeEvents im Schema definiert.
    2. Statuswerte `NEW`, `ACTIVE`, `UPDATED`, `CLOSED`, `REMOVED`, `INVALID` sowie Scanstatus, Fehlerklassen, Prioritäten und Klassifikationsergebnisse festgelegt.
    3. Dokumentation mit Speicherentscheidung, Identitätspriorität, Beispieldokument und Negativregeln ergänzt.
  - [x] Evidence: `schemas/jobagent.schema.json`, `docs/data-model.md`, `tests/fixtures/jobagent/valid.json`, `tests/fixtures/jobagent/invalid-missing-official-url.json`, `tests/fixtures/jobagent/invalid-missing-job-id.json`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` exit=0; `npx --yes --package ajv-cli@5 --package ajv-formats ajv validate -s schemas\jobagent.schema.json -d tests\fixtures\jobagent\valid.json --spec=draft2020 -c ajv-formats` exit=0; `.\ci.cmd self-check` exit=0.
  - [x] Audit: Keine Felder erzwingen personenbezogene Bewerbungsdaten; fehlende optionale Informationen werden mit `UNKNOWN` modelliert; `JobSource` akzeptiert nur offizielle Quellen.
  - [x] Supertest: Nicht ausgeführt; JA-013 bündelt abgeschlossene Funktionsbereiche später in einen projektspezifischen Supertest.

- [x] JA-001 Programmvertrag und Akzeptanzkriterien für den JobAgent verbindlich festlegen #comment: Der fachliche Auftrag aus dem Nutzerbriefing wurde in eine prüfbare Projektanweisung übersetzt, bevor Code oder Datenbankstruktur entstehen.
  - [x] Beschreibung: `manual/PROGRAM.md` enthält den Zweck des JobAgent, das Zielprofil für IT-Fuehrungspositionen, das Zielgebiet Muenchen 20 km/Freising, erlaubte Quellen, ausgeschlossene Quellen, Laufmodus, Persistenzpflichten, Ausgabeformat und harte No-Gos; jede Anforderung ist als überprüfbare Muss-/Soll-/Darf-nicht-Regel formuliert.
  - [x] Scope: Bearbeitet wurde `manual/PROGRAM.md`; keine CI-Runtime-Dateien wurden fachlich geändert; keine Recherchelogik wurde in Dokumentationsdateien implementiert.
  - [x] Ist-Stand (2026-08-17 12:36): `manual/PROGRAM.md` ist kein Platzhalter mehr, sondern enthält den verbindlichen JobAgent-Programmvertrag.
  - [x] Abhängigkeiten: README-Regeln, Nutzerauftrag, Roadmap und Bootstrap-Dateien wurden berücksichtigt; keine fachlichen Vorarbeiten waren erforderlich.
  - [x] Aufwand/Dauer: Aufwand M, umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 100/100, weil ohne verbindlichen Programmvertrag alle nachfolgenden Datenmodelle, Tests und Crawler spekulativ wären.
  - [x] Risiken: Persistenztechnologie, Firmen-Seedliste, Geodistanzlogik, konkrete ATS-Systeme und Scheduler bleiben als `UNKNOWN` in `manual/PROGRAM.md` dokumentiert.
  - [x] Schritte:
    1. Nutzerauftrag in `manual/PROGRAM.md` strukturiert nach Zweck, Zielprofil, Zielgebiet, Quellenpriorität, Persistenz, Statusmodell, Daily Workflow, Deduplikation, Ausgabeformat, Qualitätssicherung, Betrieb und offenen Annahmen.
    2. Akzeptanzkriterien ergänzt, u.a. keine Treffer ohne offizielle URL, keine erfundenen Daten, keine erneute `NEW`-Ausgabe bekannter unveränderter Stellen und kein automatisches Schließen bei Scanfehlern.
    3. Offene technische Entscheidungen als `UNKNOWN` dokumentiert, statt Datenbanktyp, Scheduler oder ATS-Abdeckung zu erfinden.
  - [x] Evidence: `manual/PROGRAM.md` enthält die fachlichen Pflichtabschnitte; `logs/terminal/self-check-20260817-123608.log` belegt grüne Basisprüfung; Kernbegriffsuche bestätigte `IT-Fuehrungspositionen`, `offizielle`, `NEW`, `CLOSED`, `Muenchen`, `Freising`, `keine nicht belegten`.
  - [x] Funktionstest: `.\ci.cmd self-check` lief mit exit=0 und issues=0; textuelle Contract-Prüfung per `Select-String` auf Kernbegriffe lief mit exit=0.
  - [x] Audit: Keine widersprüchlichen Regeln zu Quellen, Statuswerten oder Zielgebiet im Programmvertrag festgestellt; nicht belegbare Informationen sind verboten oder als `UNKNOWN` markiert.
  - [x] Supertest: Vom Nutzer nicht angefragt; gemäß Nutzeranweisung für diesen Abschluss als erledigt gewertet, ohne separaten Lauf.
