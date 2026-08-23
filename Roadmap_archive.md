# Roadmap Archive

## Archiviert am 2026-08-17

- [x] JA-022 Lokale App-/Artefaktablage, Devserver-Port und Visual-Audit für HTML-Berichte absichern #comment: Die App laeuft nur lokal; Berichte muessen reproduzierbar abgelegt, geoeffnet und visuell geprueft werden koennen.
  - [x] Beschreibung: Der lokale Static-/Devserver wird ueber `.\ci.cmd` im Hintergrund auf Port `8500` betrieben, HTML-Reports werden reproduzierbar unter `html/jobagent/` abgelegt und ein lokaler Viewport-Audit liefert belastbare Nachweise fuer `1920`, `1366` und `800` Pixel Breite.
  - [x] Scope: Umgesetzt wurden Anpassungen in `.ci/ci.config.json`, `.ci/bin/modules/browser-logic.ps1`, `.ci/bin/modules/ci-core.ps1`, `src/JobAgent.Operations.psm1`, `src/JobAgent.Report.psm1`, `tests/Test-JobAgentOperations.ps1`, `tests/Test-JobAgentHtmlAudit.ps1` und `tests/Test-JobAgentHtmlViewportAudit.ps1`. No-Go blieb eingehalten: kein blockierender Vordergrundserver, kein Start ausserhalb `.\ci.cmd`, kein blindes Beenden fremder Prozesse.
  - [x] Ist-Stand (2026-08-23 07:36): Der Devserver-Vertrag ist auf `8500` vereinheitlicht, der lokale Audit-Report ist per HTTP `200` unter `http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html` erreichbar, HTML-/Markdown-/JSON-Artefakte liegen reproduzierbar im Repo und Screenshots fuer `1920`, `1366` und `800` Breite wurden erzeugt.
  - [x] Abhängigkeiten: JA-016 und JA-017 lieferten HTML-Artefakte und die sichtbaren Pflichtfelder; der Abschluss nutzte die bestehende lokale Reporting- und Betriebs-Lane.
  - [x] Aufwand/Dauer: Aufwand M; innerhalb der aktuellen Arbeitseinheit fachlich abgeschlossen.
  - [x] Prioritätsscore: 72/100, weil lokale Bedienbarkeit und Abnahmefaehigkeit fuer die HTML-Berichte jetzt vertraglich belegt sind.
  - [x] Ordnungsbegründung: Nach vorhandenem HTML-Output wurde die lokale Betriebs- und Sichtbarkeits-Haertung abgeschlossen, damit der tatsaechlich ausgelieferte Bericht pruefbar ist.
  - [x] Risiken und Unsicherheiten: Portkonflikte auf `8500` bleiben ein Betriebsrisiko; die `800px`-Ansicht nutzt bewusst horizontales Tabellen-Scrolling statt eines separaten Kartenlayouts. SonarQube auf `:9000` blieb ausserhalb dieses Punkts offen.
  - [x] Schritte:
    1. Devserver-Port und Statuspersistenz auf `8500` gehaertet; `html_report_path` wurde im Betriebsstatus verankert.
    2. Lokalen HTML-Audit-Test fuer Pflichtsektionen, Overflow-Schutz, fehlende externe Runtime-Ressourcen und offizielle Links erstellt.
    3. Reproduzierbaren Viewport-Audit mit Artefakterzeugung fuer `1920/1366/800` umgesetzt und das Handoff auf konkrete JSON-/Markdown-/HTML-Reportpfade sowie Screenshot-Pfade zugespitzt.
  - [x] Evidence: `html/jobagent/ja-022-viewport-audit.html`, `logs/jobagent/ja-022-viewport-audit.md`, `logs/jobagent/ja-022-viewport-audit.json`, `output/playwright/ja-022-viewport-1920.png`, `output/playwright/ja-022-viewport-1366.png`, `output/playwright/ja-022-viewport-800.png`, `logs/devserver/devserver.log`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentOperations.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0; `.\ci.cmd devserver-start` -> Exit 0; `Invoke-WebRequest http://127.0.0.1:8500/` -> HTTP 200.
  - [x] Audit: Viewport-Screenshots fuer `1920`, `1366` und `800` liegen vor; der lokale Server liefert HTML ohne externe Runtime-Ressourcen; Job-Tabellen bleiben lesbar und scrollen auf kleinen Viewports horizontal statt Spalten unkontrolliert zusammenzudruecken.
  - [x] Supertest: Nicht separat angefragt; gemaess Nutzeranweisung fuer diesen Abschluss als erledigt gewertet.

- [x] JA-021 Firmeninventar autonom, dedupliziert und quellenorientiert erweitern #comment: Die Firmenbasis wird jetzt ueber verifizierte Discovery-Feeds und Seeds ausgebaut, ohne Dubletten oder falsche Verifikation zu erzeugen.
  - [x] Beschreibung: Der JobAgent importiert neue Unternehmen aus gepflegten Discovery-Feeds oder Seeds, unterscheidet offizielle Quellen von `DISCOVERY_HINT`/`MANUAL_REVIEW`, fuehrt Dubletten ueber ID, Domain und rechtsformnormalisierte Namen zusammen und persistiert Prioritaet, Zielgebiet, Discovery-Herkunft und Verifikationsstatus verlustfrei.
  - [x] Scope: Erweitert wurden `src/JobAgent.CompanyInventory.psm1`, `tools/Import-JobAgentCompanyDiscovery.ps1`, `data/jobagent/company-discovery.official.json`, `tests/Test-JobAgentCompanyInventory.ps1` und der produktive Store `data/jobagent/store.json`. `src/JobAgent.Coverage.psm1` blieb inhaltlich unveraendert, wurde aber gegen das neue Discovery-Verhalten erneut verifiziert. No-Go blieb eingehalten: keine neue Firma ohne belastbare offizielle Quelle im produktiven Feed, keine Zusammenfuehrung rechtlich getrennter Arbeitgeber ohne Identitaetsbeleg.
  - [x] Ist-Stand (2026-08-17 18:05): Der Store wurde von 12 auf 20 Firmen erweitert. Neu aufgenommen wurden `Microsoft Deutschland GmbH`, `Google Germany GmbH`, `MAN Truck & Bus SE`, `Knorr-Bremse AG`, `BWI GmbH`, `Bayerische Landesbank`, `Versicherungskammer Bayern` und `msg systems ag`. Discovery-Importe koennen jetzt auch unverifizierte Hinweisquellen fuer spaeteren Manual Review modellieren, ohne offizielle JobSources vorzutaeuschen.
  - [x] Abhängigkeiten: JA-004, JA-015, JA-019 und JA-020 waren abgeschlossen und lieferten Seed-Grundlage, Priorisierungslogik, persistente Quellenbelege und robuste Live-/ATS-Verifikation.
  - [x] Aufwand/Dauer: Aufwand L; innerhalb der aktuellen Arbeitseinheit fachlich abgeschlossen.
  - [x] Prioritätsscore: 78/100, weil breitere Firmenabdeckung die Trefferwahrscheinlichkeit direkt erhoeht und jetzt mit sauberer Quellenbeweiskette abgesichert ist.
  - [x] Ordnungsbegründung: Nach Härtung von Report, Status, Quellenbelegen und Live-Adaptern konnte die Firmenbasis ohne unsichere Historienmutation erweitert werden.
  - [x] Risiken und Unsicherheiten: Vollstaendigkeit bleibt unbelegt; Karriere-URLs und Standortbezuge muessen bei kuenftigen Feed-Updates weiter offiziell geprueft werden. `DISCOVERY_HINT` bleibt absichtlich unverifiziert, bis eine offizielle Firmen- oder Karrierequelle nachgezogen wird.
  - [x] Schritte:
    1. Discovery-Vertrag in `New-JobAgentCompanySeed` und `ConvertTo-JobAgentCompanyDiscoverySeed` erweitert: `verification_url`, `discovery_origin`, `target_area`, `industry_hint`, `evidence_note`, `UNVERIFIED` fuer Hinweisquellen.
    2. Import-Lane `Import-JobAgentCompanyDiscoveryInventory` und CLI `tools/Import-JobAgentCompanyDiscovery.ps1` erstellt, inklusive deduplizierter Merge-Logik, Backup und Import-Log.
    3. Offiziellen Discovery-Feed fuer acht weitere Arbeitgeber gepflegt und in den produktiven Store importiert; Funktionstests fuer Manual-Review-Importe, offizielle Website-only-Faelle und Script-Import ergaenzt.
  - [x] Evidence: `data/jobagent/company-discovery.official.json`; `logs/jobagent/company-discovery-import-20260817-160219.json`; `data/jobagent/store.json` mit 20 Firmen und 20 offiziellen Quellen.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentPersistence.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentSchema.ps1` -> Exit 0; `pwsh -NoProfile -File tools\Import-JobAgentCompanyDiscovery.ps1` -> Exit 0.
  - [x] Audit: Produktiver Feed verwendet nur offizielle Quellen; neue Firmen tauchen nach erneutem Import nicht doppelt auf; unverifizierte Discovery-Hinweise erzeugen keine offizielle Karrierequelle und bleiben fuer manuellen Review markiert.
  - [x] Supertest: Nicht neu angefragt; gemaess Nutzeranweisung fuer diesen Abschluss als erledigt gewertet.

- [x] JA-020 Live-Adapter von Pilotqualitaet auf robuste offizielle Karriereseiten- und ATS-Erkennung erweitern #comment: Die Live-Lane verarbeitet jetzt statische Karriereseiten, JSON-LD und strukturierte ATS-Listen deterministisch, begrenzt und fail-closed.
  - [x] Beschreibung: Live-Scans erkennen statische Karriereseiten, Such-/Listen-Seiten und mehrere explizit belegte ATS-Strukturen deterministisch, begrenzt und fail-closed; jedes Ergebnis enthaelt offizielle Detail-URL, HTTP-/Fetch-Nachweis, Extraktionsvertrauen, Klassifikation und Fehlerklasse.
  - [x] Scope: Erweitert wurden `src/JobAgent.LiveScan.psm1`, `tests/Test-JobAgentLiveScan.ps1` und mittelbar die bestehende Daily-Run-Lane ueber die Live-Adapter-Verwendung. `src/JobAgent.SourceAdapters.psm1` blieb vertraglich unveraendert, wurde aber gegen die neue Extraktion erneut verifiziert. No-Go blieb eingehalten: kein Login-/Captcha-Bypass, kein Aggregator als Primaerquelle, keine ungebremste Volltextsuche, keine Live-Abhaengigkeit in deterministischen Funktionstests.
  - [x] Ist-Stand (2026-08-17 17:48): `Invoke-JobAgentLiveHtmlAdapter` verarbeitet jetzt offizielle HTML-Linklisten, JSON-LD-`JobPosting`, Workday-aehnliche ATS-URLs, Greenhouse-Detailseiten und strukturierte ATS-JSON-Listen mit Feldern wie `postings`, `hostedUrl`, `absolute_url`, `id`, `categories.location`, `categories.commitment` und `descriptionPlain`. Leere, blockierte, dynamische oder fehlerhafte Quellen bleiben fail-closed als `NO_JOBS_FOUND`, `BLOCKED`, `TECHNICAL_LIMITATION` oder `TIMEOUT` klassifiziert.
  - [x] Abhaengigkeiten: JA-018 und JA-019 waren abgeschlossen und liefern die benoetigte Status- und Verifikationssicherheit; JA-021 und JA-022 bauen nun auf der gehaerteten Live-Lane auf.
  - [x] Aufwand/Dauer: Aufwand L; innerhalb der aktuellen Arbeitseinheit fachlich abgeschlossen.
  - [x] Prioritaetsscore: 82/100, weil die Live-Abdeckung jetzt belastbar genug fuer die nachgelagerte Firmenabdeckung ist.
  - [x] Ordnungsbegruendung: Nach Quellenbeweiskette und Statushaertung wurde die Live-Lane auf robuste offizielle Karriere- und ATS-Muster erweitert, bevor das Firmeninventar weiter skaliert.
  - [x] Risiken und Unsicherheiten: Weitere Karriereportale koennen spaeter eigene Muster benoetigen; JavaScript-only-Seiten ohne verwertbare strukturierte Daten bleiben bewusst `TECHNICAL_LIMITATION` oder `MANUAL_REVIEW` statt falscher Treffer.
  - [x] Schritte:
    1. JSON-LD-Extraktion gegen primitive und uneinheitliche Nodes gehaertet und auf offizielle Detailseiten begrenzt.
    2. ATS-Erkennung um Workday-aehnliche Pfade, Greenhouse-Detailseiten und strukturierte ATS-JSON-Listen erweitert, inklusive kanonisierter Detail-URL, Job-ID, Ort und Beschaeftigungsart.
    3. Deterministische Funktionstests fuer strukturierte ATS-Listen, blockierte Quellen, dynamische App-Shells, blockierte Detailfetches und Timeout-Detailfetches ergaenzt und gegen Daily-Run verifiziert.
  - [x] Evidence: `src/JobAgent.LiveScan.psm1`, `tests/Test-JobAgentLiveScan.ps1`, aktualisierte Handoff-/Todo-Artefakte nach `./ci.cmd stp`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentDailyRun.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0.
  - [x] Audit: Aggregatoren bleiben ausgeschlossen; nur offizielle Firmen-, Karriere- oder belegte ATS-Quellen werden akzeptiert; blockierte, dynamische oder nicht erreichbare Seiten erzeugen keine verifizierten Treffer.
  - [x] Supertest: Vom Nutzer fuer diesen Abschluss nicht separat angefragt; gemaess Nutzeranweisung als erledigt gewertet.
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
## Archiviert am 2026-08-23

- [x] JA-023 Quellenkatalog fuer maximale Firmen-Discovery nach Evidenzklasse erstellen #comment: Vollstaendigkeit ist nur steuerbar, wenn jede nutzbare Quelle mit Herkunft, Lizenz-/Nutzungsgrenze, Belegtyp und Importentscheidung katalogisiert ist.
  - [x] Beschreibung: Es existiert ein maschinenlesbarer Discovery-Quellenkatalog, der alle geprueften Quellenklassen fuer Muenchen, Muenchen 20 km und Freising nach `OFFICIAL_DIRECTORY`, `PUBLIC_JOBBOARD_HINT`, `BUSINESS_NETWORK_HINT`, `REGISTER_HINT`, `STARTUP_CLUSTER_HINT`, `SECTOR_CLUSTER_HINT`, `MANUAL_REVIEW_ONLY` und `REJECTED` klassifiziert; jede Quelle enthaelt URL, Betreiber, erlaubte Nutzung im JobAgent, erwartete Felder, Verifikationsanforderung, Rate-/Robots-Hinweis und Importprioritaet.
  - [x] Scope: Geaendert/erstellt wurden `data/jobagent/company-discovery.sources.json`, `schemas/jobagent.discovery-source.schema.json`, `src/JobAgent.Coverage.psm1`, `tests/Test-JobAgentCoverage.ps1` und `docs/data-model.md`. No-Go: keine Firma direkt in `data/jobagent/store.json` schreiben, keine Scraping-Regeln fuer Login/Captcha/Paywall, keine Sekundaerquelle als offizielle Karrierequelle markieren.
  - [x] Ist-Stand (2026-08-23 08:30): Der Quellenkatalog ist als `data/jobagent/company-discovery.sources.json` umgesetzt, gegen `schemas/jobagent.discovery-source.schema.json` validiert und in Coverage-Auswertung, Dokumentation und Funktionstest eingebunden.
  - [x] Abhängigkeiten: Keine fachliche Code-Abhaengigkeit ausser JA-021/JA-022; dieser Punkt ist Grundlage fuer JA-024 bis JA-027.
  - [x] Aufwand/Dauer: Aufwand M; Annahme 1 Entwickler/Agent, 0,5-1 Arbeitstag fuer Schema, Katalog, Tests und Dokumentation ohne produktiven Massenimport.
  - [x] Prioritätsscore: 100/100, weil ohne deterministischen Quellenvertrag jede breite Firmenaufstockung uneinheitlich, schwer auditierbar und dublettenanfaellig bleibt.
  - [x] Ordnungsbegründung: Grundlagen vor Import: Erst Quellen, Evidenzklassen und No-Gos festlegen, dann konkrete Arbeitgeber importieren.
  - [x] Risiken und Unsicherheiten: Nutzungsbedingungen einzelner Verzeichnisse koennen automatisches Auslesen begrenzen; einige Quellen liefern nur Namen ohne Website; private Verzeichnisse koennen veralten oder Dubletten enthalten; offizielle APIs fuer Handelsregister/Unternehmensregister sind fuer allgemeine Suche nicht gesichert verfuegbar.
  - [x] Schritte:
    1. Schema und Beispieldaten fuer `company-discovery.sources.json` erstellen; jede Quelle muss `source_id`, `source_url`, `operator`, `source_class`, `allowed_use`, `expected_fields`, `verification_required`, `rate_limit_note`, `robots_note`, `priority`, `last_reviewed_at` und `rejection_reason` validieren.
    2. Coverage-Auswertung erweitern, damit Quellebene und Firmenebene getrennt reportet werden: Anzahl Quellen je Klasse, importierbare Quellen, abgelehnte Quellen, manuelle Review-Quellen und offene Verifikationsluecken.
    3. Katalog initial mit mindestens diesen Quellenklassen fuellen: Stadt Muenchen Wirtschaft/boersennotierte Unternehmen, EMM-Mitglieder, EMM-Branchencluster, Landkreis/Freising/Weihenstephan, BA-Jobsuche, Make it in Germany, EURES, Berufsstart/Yourfirm/Karriereakademie als Sekundaerhinweis, Unternehmensregister/Handelsregister als Registerhinweis.
  - [x] Evidence: `data/jobagent/company-discovery.sources.json`, `schemas/jobagent.discovery-source.schema.json`, `logs/jobagent/ja-023-source-coverage.json` und Dokumentationsabschnitt `Discovery Source Registry` in `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1` -> Exit 0; JSON-Schema-Validierung fuer `data/jobagent/company-discovery.sources.json` gegen `schemas/jobagent.discovery-source.schema.json` ist Teil des Funktionstests.
  - [x] Audit: Manuell pruefen, dass jede Quelle genau eine Klasse hat, dass Sekundaerquellen keine `OFFICIAL_WEBSITE`-Semantik erhalten, dass Nutzungs-/Robots-Hinweise nicht leer sind und dass Quellen ohne gesicherte Nutzung als `MANUAL_REVIEW_ONLY` oder `REJECTED` markiert sind.
  - [x] Supertest: `pwsh -NoProfile -File tests\\Test-JobAgentSupertest.ps1` -> Exit 0.
  - [x] Meilenstein: M1 Quellenvertrag; parallelisierbar mit JA-024 nur fuer reine manuelle Quellenrecherche, nicht fuer Schema-/Katalogformat.

## Archiviert am 2026-08-23

- [x] JA-024 Offizielle regionale Arbeitgeberlisten in Discovery-Feed importieren #comment: Oeffentliche und halb-offizielle Standortlisten liefern den schnellsten qualitaetsgesicherten Zuwachs, muessen aber pro Arbeitgeber gegen Website und Karrierepfad belegt werden.
  - [x] Beschreibung: Aus den priorisierten regionalen Quellen wurden Arbeitgeberkandidaten fuer Muenchen, Muenchen 20 km und Freising in einen neuen kuratierten Feed importiert; jeder Kandidat enthaelt kanonischen Namen, offizielle Website, Karriere-URL, Zielgebiet, Quellenbeleg, Branche, Prioritaet und Reviewstatus, ohne dass unverifizierte Hinweise als JobSource erzeugt werden.
  - [x] Scope: Geaendert/erstellt wurden `data/jobagent/company-discovery.regional.json`, `tools/Import-JobAgentCompanyDiscovery.ps1`, `src/JobAgent.CompanyInventory.psm1`, `tests/Test-JobAgentCompanyInventory.ps1`, `docs/data-model.md` und `data/jobagent/store.json`. No-Go eingehalten: keine Arbeitgeber ohne Unternehmenswebsite in den produktiven Store uebernommen; keine Karriere-URL aus Aggregator oder Jobboerse uebernommen; bestehende Firmen wurden dedupliziert.
  - [x] Ist-Stand (2026-08-23 08:20): Regionaler Feed enthaelt 20 Arbeitgeberkandidaten; produktiver Import erhoehte den Store auf 38 Firmen und 38 offizielle JobSources. 18 Firmen wurden neu hinzugefuegt, Flughafen Muenchen und Texas Instruments wurden aktualisiert/dedupliziert.
  - [x] Abhängigkeiten: JA-023 war abgeschlossen und lieferte Quellenklassen und Katalogformat.
  - [x] Aufwand/Dauer: Aufwand L; umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 94/100, weil offizielle regionale Listen hohe Trefferwahrscheinlichkeit bei niedrigerem Falschpositiv-Risiko liefern und den produktiven Store sofort deutlich vergroessert haben.
  - [x] Ordnungsbegründung: Nach Quellenvertrag wurden die quellenstaerksten regionalen Arbeitgeber vor breiteren Jobboersen-Hinweisen importiert.
  - [x] Risiken und Unsicherheiten: Einige Karrierepfade sind globale Jobportale und benoetigen spaeter Standort-/Stellenfilter; die manuelle Stichprobe wurde durch HTTP-/Suchbelege und Aggregator-Guardrails ergaenzt, ersetzt aber keine tiefe ATS-Verifikation aus JA-026.
  - [x] Schritte:
    1. Kandidaten aus der Muenchen-Boersenquelle, Landkreis-Freising-Wirtschaft und Freising-Weihenstephan extrahiert; pro Kandidat `discovery_origin` auf die konkrete Quelle gesetzt.
    2. Pro Kandidat offizielle Website und Karrierepfad gepflegt; fehlende ATS-Bindings werden nicht mehr als `null` gespeichert.
    3. Feed importiert und Deduplikationsreport erzeugt: 20 importierte Kandidaten, 18 neue Firmen, 2 aktualisierte/deduplizierte Firmen, 0 Manual-Review-Faelle.
  - [x] Evidence: `data/jobagent/company-discovery.regional.json`, `logs/jobagent/company-discovery-regional-import-20260823-062001.json`, `logs/jobagent/company-discovery-regional-import-20260823-062056.json`, `data/jobagent/store.json`, Dokumentationsabschnitt `Regionaler Firmen-Discovery-Feed` in `docs/data-model.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tools\\Import-JobAgentCompanyDiscovery.ps1 -FeedPath data\\jobagent\\company-discovery.regional.json` -> Exit 0.
  - [x] Audit: Tests pruefen Feed-Schema, Mindestanzahl, Quellenherkunft, keine Aggregator-Karriere-URLs, keine doppelten offiziellen Domains, Import ohne Manual-Review-Backlog und keine `null`-ATS-Bindings; produktiver Import meldete `manual_review_required: []`.
  - [x] Supertest: `pwsh -NoProfile -File tests\\Test-JobAgentSupertest.ps1` -> Exit 0.
  - [x] Meilenstein: M2 regionaler Arbeitgeberkern; Basis fuer JA-025 und JA-026.

## Archiviert am 2026-08-23

- [x] JA-025 Sekundaere Job- und Unternehmensverzeichnisse als Hinweisquellen operationalisieren #comment: Jobboersen und Firmenprofile koennen viele Arbeitgeber sichtbar machen, duerfen aber nur Discovery-Hints erzeugen, bis eine offizielle Karrierequelle bestaetigt ist.
  - [x] Beschreibung: BA-Jobsuche, Make it in Germany, EURES sowie regionale Firmen-/Arbeitgeberverzeichnisse werden als kontrollierte Hinweisquellen angebunden; der Import erzeugt ausschliesslich `DISCOVERY_HINT`-Kandidaten mit Suchparametern, Fund-URL, Arbeitgebername, Ort, Branche/Keyword und spaeterer Pflichtverifikation gegen offizielle Website/Karriere-URL.
  - [x] Scope: Erstellt wurde `tools/Find-JobAgentCompanyDiscoveryHints.ps1` und `data/jobagent/company-discovery.hints.json`; erweitert wurden `src/JobAgent.CompanyInventory.psm1`, `tests/Test-JobAgentCompanyInventory.ps1` und `tests/Test-JobAgentCoverage.ps1`. No-Go eingehalten: keine Stellen aus Sekundaerquellen als Treffer gespeichert, keine BA/EURES/Make-it-in-Germany-URL als offizielle Bewerbung-URL akzeptiert, kein dynamisches UI/Login/Captcha umgangen.
  - [x] Ist-Stand (2026-08-23 08:31): Die Hint-Lane erzeugt eine 72er Suchmatrix aus Zielorten und IT-Fuehrungskeywords, persistiert 6 unverifizierte Sekundaerhinweise in `data/jobagent/company-discovery.hints.json`, markiert bekannte Firmen ueber bestehende Store-Identitaeten und erzeugt ein Laufprotokoll unter `logs/jobagent/company-discovery-hints-20260823-063057.json`.
  - [x] Abhängigkeiten: JA-023 und JA-024 sind abgeschlossen; die Hint-Lane nutzt den Quellenkatalog und den bestehenden Firmenstore nur lesend.
  - [x] Aufwand/Dauer: Aufwand L; umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent mit Fixture-/Seed-Modus ohne Live-Massenimport.
  - [x] Prioritätsscore: 82/100, weil diese Quellen die Abdeckung vergroessern koennen, aber ein hoeheres Falschpositiv- und Nutzungsgrenzenrisiko haben.
  - [x] Ordnungsbegründung: Nach regionalen offiziellen Quellen umgesetzt, weil Jobboersen nur Entdeckung liefern und zwingend nachgelagerte Firmen-/Karriereverifikation brauchen.
  - [x] Risiken und Unsicherheiten: Es wurde kein Live-Massenabruf aktiviert; die aktuellen Hints sind kontrollierte, unverifizierte Hinweise. Tagesaktuelle Jobboersenfluktuation, Recruiter-/Zeitarbeits-Treffer und Nutzungsbedingungen bleiben fuer spaetere Live-Erweiterungen als Risiko bestehen.
  - [x] Schritte:
    1. Suchmatrix fuer `Muenchen`, `Freising`, `Garching`, `Unterfoehring`, `Ismaning`, `Taufkirchen`, `Neubiberg`, `Pullach`, `Gruenwald` mit 20/25-km-Radius und acht IT-Fuehrungskeywords implementiert.
    2. Hint-Erzeugung gebaut, die pro Treffer nur Arbeitgebername, Ort, Sekundaerquelle, Suchparameter, beobachtete URL, Zeitstempel, `verification_status = UNVERIFIED` und bekannte Store-Identitaet speichert.
    3. Review-Report/Hint-Store erzeugt, der alle Kandidaten fail-closed als `DISCOVERY_HINT` ausweist und keine JobSources oder offiziellen Karrierequellen schreibt.
  - [x] Evidence: `tools/Find-JobAgentCompanyDiscoveryHints.ps1`, `data/jobagent/company-discovery.hints.json`, `logs/jobagent/company-discovery-hints-20260823-063057.json`, Coverage-Testfall `secondary_hint_store_contract`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tools\\Find-JobAgentCompanyDiscoveryHints.ps1` -> Exit 0.
  - [x] Audit: Tests pruefen, dass keine Hint-Quelle eine JobSource erzeugt, alle Hints `UNVERIFIED` bleiben, Suchparameter/Fund-URLs vorhanden sind, nur erlaubte Sekundaerquellen referenziert werden und bekannte Firmen markiert statt dupliziert werden.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0.
  - [x] Meilenstein: M3 breiter Discovery-Hint-Backlog; Basis fuer JA-026.
## Archiviert am 2026-08-23

- [x] JA-026 Automatische Karrierepfad- und ATS-Verifikation fuer Firmenkandidaten bauen #comment: Viele Kandidaten haben nur Website oder Namen; skalierbare Aufstockung braucht einen fail-closed Verifizierer fuer Karrierepfade und offiziell verlinkte ATS.
  - [x] Beschreibung: Ein Verifikationslauf nimmt Firmenkandidaten aus regionalen Feeds und Hint-Backlog, sucht auf der offiziellen Website deterministisch nach Karriere-/Jobs-/Stellenangebot-/Sitemap-/ATS-Links, bewertet Redirects und speichert nur dann `CAREER_URL_VERIFIED`, wenn der Karrierepfad auf offizieller Domain liegt oder von der offiziellen Website belegbar auf eine ATS-Domain fuehrt.
  - [x] Scope: Neu/zu aendern sind `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.LiveScan.psm1`, `tools/Verify-JobAgentCompanyCareers.ps1`, `tests/Test-JobAgentSourceVerification.ps1`, `tests/Test-JobAgentLiveScan.ps1` und `tests/Test-JobAgentCompanyInventory.ps1`. No-Go: keine Suchmaschinen-Snippets als Beleg, kein Erraten von `/jobs` ohne HTTP-/HTML-Beleg, keine globale ATS-Allowlist ohne Firmenlink, keine mehrstufige aggressive Crawl-Tiefe.
  - [x] Ist-Stand (2026-08-23 09:07): Der Verifizierer, Batch-CLI, Fixture-Abdeckung und produktive Auditlauf sind abgeschlossen. Der Store enthaelt 38 Firmen mit `CAREER_URL_VERIFIED`; der Batchlauf fand keine offenen unverifizierten Zielkandidaten mehr. Der Live-Audit pruefte 38 Karriere-URLs, davon 36 mit HTTP-Erfolg; BMW Group lief in der lokalen Umgebung in ein Timeout und Fraunhofer IVV lieferte fuer die gespeicherte Career-URL HTTP 404, beide bleiben als Review-Hinweis fuer JA-027/naechste Pflegewelle sichtbar.
  - [x] Abhängigkeiten: Abhaengig von JA-023; profitiert von JA-024/JA-025, kann aber gegen bestehende 20 Firmen und synthetische Fixtures vorab implementiert werden.
  - [x] Aufwand/Dauer: Aufwand XL; Annahme 1 Entwickler/Agent, 2-4 Arbeitstage fuer Heuristik, Redirect-/Sitemap-Parsing, ATS-Beleglogik, Fixture-Abdeckung und begrenzten Live-Smoke.
  - [x] Prioritätsscore: 90/100, weil dieser Punkt den Engpass zwischen vielen Firmenhinweisen und offiziell nutzbaren JobSources schliesst.
  - [x] Ordnungsbegründung: Nach ersten regionalen Kandidaten muss Verifikation skalieren, damit die Liste nicht manuell bei jedem Arbeitgeber gepflegt werden muss.
  - [x] Risiken und Unsicherheiten: Viele Websites sind JavaScript-only, mehrsprachig oder nutzen Consent-Gates; Karrierebereiche koennen ausgelagert sein; ATS-Links koennen in Scripts statt HTML stehen; zu tiefer Crawl kann langsam oder unerwuenscht sein; fehlender Beleg muss fail-closed bleiben.
  - [x] Schritte:
    1. Deterministische Linksuche implementieren: Homepage, robots-/sitemap-verträgliche Sitemap-URLs, sichtbare Links mit Text/Path-Mustern `karriere`, `career`, `jobs`, `stellen`, `stellenangebote`, `workday`, `successfactors`, `greenhouse`, `smartrecruiters`, `personio`, `recruitee`, maximal definierte Fetch-Anzahl je Firma.
    2. Verifikationsentscheidung erweitern: `COMPANY_DOMAIN_VERIFIED`, `CAREER_URL_VERIFIED`, `ATS_VERIFIED_BY_COMPANY_LINK`, `MANUAL_REVIEW`, `TECHNICAL_LIMITATION`, inklusive Redirect-Kette, Basis-URL, HTTP-Status, Linktext und Begründung im `verification_evidence`.
    3. Batch-Tool bauen, das Kandidaten priorisiert, bestehende Firmen aktualisiert, keine Dubletten erzeugt, Review-Faelle exportiert und pro Lauf ein maschinenlesbares Auditlog schreibt.
  - [x] Evidence: `tools/Verify-JobAgentCompanyCareers.ps1`, Verifikationslog `logs/jobagent/company-career-verification-20260823-070101.json`, Auditlog `logs/jobagent/company-career-audit-20260823-070635.json`, Auditbericht `logs/jobagent/company-career-audit-20260823-070635.md`, aktualisierte Verifizierungsfunktionen in `src/JobAgent.SourceVerification.psm1` und Fixture-Abdeckung fuer Domain-, Redirect-, ATS-, JS-only- und Manual-Review-Faelle.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
  - [x] Audit: `logs/jobagent/company-career-audit-20260823-070635.json` auditiert 38 verifizierte Firmen, davon 36 HTTP-erfolgreich; mindestens 20 offiziell gepflegte Karriere-URLs sind damit belegt. Keine Aggregator-URL wurde akzeptiert; BMW Timeout und Fraunhofer-IVV-404 bleiben als technische bzw. Pflege-Risiken dokumentiert.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0.
  - [x] Meilenstein: M4 skalierbare Quellenverifikation abgeschlossen; JA-027 kann auf Audit- und Coverage-Artefakten aufsetzen.
## Archiviert am 2026-08-23

- [x] JA-027 Firmen-Coverage-Audit und priorisierte Importwellen fuer maximale Abdeckung einfuehren #comment: Nach Quellen- und Verifikationsaufbau braucht der JobAgent messbare Abdeckung nach Region, Branche, Quelle und Reviewstatus, damit die Liste systematisch waechst.
  - [x] Beschreibung: Der JobAgent erzeugt einen Coverage-Audit fuer Firmeninventar und Discovery-Backlog mit Zielwerten je Welle; Importwellen priorisieren offizielle/verifizierte Arbeitgeber aus grossen IT-relevanten Branchen, Grossarbeitgebern, oeffentlichem Sektor, Hochschulen/Forschung, Flughafen/Freising, Startups/Scaleups und Dienstleistern, bis alle Kandidaten mit Website und Karriere-/Jobs-Seite entweder importiert, dedupliziert oder begruendet verworfen sind.
  - [x] Scope: Geaendert/erstellt wurden `src/JobAgent.Coverage.psm1`, `tools/Measure-JobAgentCompanyCoverage.ps1`, `logs/jobagent/company-coverage-20260823-072556.json`, `logs/jobagent/company-coverage-20260823-072556.md`, `html/jobagent/company-coverage.html` und `tests/Test-JobAgentCoverage.ps1`. No-Go eingehalten: keine Vollstaendigkeitsbehauptung ohne dokumentierten Nenner; unverifizierte Hints bleiben ausserhalb des Firmenbestands; der HTML-Bericht nutzt keine externen Runtime-Ressourcen.
  - [x] Ist-Stand (2026-08-23 09:28): Coverage-Audit ist implementiert und ausgefuehrt. Der aktuelle Bericht zaehlt 38 Firmen, 38 `CAREER_URL_VERIFIED`, 0 Dublettengruppen, 6 unverifizierte Discovery-Hints, 35 nie gescannte Firmen, 1 Retry-Fall und 5 priorisierte Importwellen.
  - [x] Abhängigkeiten: JA-023 bis JA-026 sind abgeschlossen; der Audit nutzt Quellenkatalog, Regionalimport, Hint-Store und Karriere-/ATS-Verifikation.
  - [x] Aufwand/Dauer: Aufwand M; umgesetzt innerhalb der aktuellen Arbeitseinheit bei 1 Agent.
  - [x] Prioritätsscore: 86/100, weil hohe Abdeckung ohne auditierbare Metriken nicht steuerbar ist und spaetere Chats sonst wieder punktuell Firmen ergaenzen.
  - [x] Ordnungsbegründung: Nach Import- und Verifikationspfad wurde die Skalierung messbar gemacht; weitere Wellen koennen jetzt nach Status, Quelle, Zielgebiet und Risiko priorisiert werden.
  - [x] Risiken und Unsicherheiten: Ein echter Vollstaendigkeitsnenner fuer den regionalen Markt bleibt nicht gesichert; Coverage ist eine operative Quote ueber bekannte Quellen und Store-Zustand. BMW Timeout und Fraunhofer-IVV-404 bleiben im Backlog als Pflege-/Retry-Risiken sichtbar.
  - [x] Schritte:
    1. Coverage-Metriken fuer Verifikationsstatus, Reviewstatus, Zielgebiet, Branche, Quellenursprung, Dubletten, Discovery-Hints, letztes Reviewdatum und Scanprioritaet implementiert.
    2. Importwellenplan umgesetzt: Welle A grosse regionale/boersennotierte Arbeitgeber, Welle B Freising/Weihenstephan/Flughafen-Umfeld, Welle C EMM/Cluster/Institutionen, Welle D BA/EURES/Make-it-in-Germany-Hints, Welle E Startup-/Scaleup- und manuelle Review-Reste.
    3. CLI-Tool erzeugt JSON-, Markdown- und HTML-Coverage-Berichte mit fail-closed Hinweistext und ohne externe Ressourcen.
  - [x] Evidence: `logs/jobagent/company-coverage-20260823-072556.json`, `logs/jobagent/company-coverage-20260823-072556.md`, `html/jobagent/company-coverage.html`, `tools/Measure-JobAgentCompanyCoverage.ps1`, Coverage-Testfaelle `coverage_tool_generates_json_markdown_html_artifacts` und `coverage_import_wave_plan`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentHtmlViewportAudit.ps1` -> Exit 0.
  - [x] Audit: HTML-Coverage-Bericht enthaelt Viewport-Meta, Overflow-Schutz und keine externen Skript-/Stylesheet-Ressourcen. Der bestehende Viewport-Audit lief ueber den lokalen Devserver bei 1920/1366/800 px mit HTTP 200 und erzeugte Screenshots unter `output/playwright/`.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0.
  - [x] Meilenstein: M5 messbare Firmenabdeckung abgeschlossen; weitere Firmenimportwellen koennen auf dem Coverage-Bericht aufsetzen.
## Archiviert am 2026-08-23

- [x] JA-023 Source Registry, Nutzungsgrenzen und Evidenzvertrag fuer massenhaftes Firmen-Discovery haerten #comment: Vor tausenden Kandidaten muessen Quellen, Erlaubnisgrenzen, Rollen und Nachweisfelder deterministisch sein, damit keine unzulaessigen oder unbelegten Firmen in den produktiven Store gelangen.
  - [x] Beschreibung: Es existiert eine versionierte Source Registry fuer mindestens diese Quellklassen: offizielle Registerportale, offene Handelsregister-Dumps, kommunale/regionale Wirtschaftslisten, Jobboersen als Arbeitgeber-Hinweise, Karriere-/ATS-Quellen als Primaerbelege und manuelle Review-Listen. Jede Quelle enthaelt `source_id`, `source_class`, `source_url`, `operator`, `allowed_use`, `forbidden_use`, `rate_limit_policy`, `robots_or_terms_note`, `expected_fields`, `evidence_level`, `freshness_policy`, `retention_policy`, `import_mode`, `review_required` und `legal_risk`. Bekannte Startquellen sind mindestens `https://www.unternehmensregister.de/`, `https://www.handelsregister.de/`, `https://offeneregister.de/daten/`, `https://www.stepstone.de/jobs/in-m%C3%BCnchen`, `https://www.stepstone.de/jobs/in-freising`, `https://www.arbeitsagentur.de/jobsuche/`, `https://de.indeed.com/`, kommunale/regionale Seiten fuer Muenchen und Freising sowie vorhandene interne Feeds unter `data/jobagent/`.
  - [x] Scope: Betroffen sind `data/jobagent/company-discovery.sources.json`, `schemas/jobagent.schema.json`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1` und neue Dokumentation `docs/company-discovery-source-contract.md`. No-Go: keine Umgehung von Login, Captcha, Robots-/Nutzungsgrenzen oder Abruflimits; keine Jobboerse als offizieller Primaernachweis; keine Aufnahme personenbezogener Registerrollen; keine automatisierte Massenabfrage offizieller Portale ohne explizites Rate-Limit.
  - [x] Ist-Stand (2026-08-23 10:00): Lokaler Store hat 38 Firmen und 38 Karrierequellen; `Roadmap.md` war auf 20 Firmen veraltet. Webrecherche zeigt als Kandidatenquellen: Unternehmensregister als zentrale Plattform fuer veroeffentlichungspflichtige Unternehmensdaten, Registerportal/Handelsregister fuer Registerdaten, OffeneRegister als nicht-offizieller Open-Data-Dump mit mehreren Millionen Firmen, StepStone-Muenchen mit ca. 9.753 bis 10.213 offenen Stellenanzeigen, sowie StepStone-Kategorien/Jobseiten mit Arbeitgebernamen. Diese Angaben sind Momentaufnahmen und muessen im Source-Contract als volatile Hinweise statt Vollstaendigkeitsbeweis behandelt werden.
  - [x] Abhängigkeiten: Keine technische Vorarbeit offen; dieser Punkt ist Grundlage fuer JA-024 bis JA-030.
  - [x] Aufwand/Dauer: Aufwand M, Dauer 1-2 PT bei 1 Entwickler/Agent; parallelisierbar nur fuer Dokumentation und Tests, nicht fuer Schemaentscheidung.
  - [x] Prioritätsscore: 100/100, weil saubere Quell- und Nutzungsgrenzen vor jeder massenhaften Erfassung zwingend sind.
  - [x] Ordnungsbegründung: Ohne Source Registry waeren nachgelagerte Importer nicht auditierbar und koennten unzulaessige oder falsch gewichtete Hinweise in den Store schreiben.
  - [x] Risiken und Unsicherheiten: Nutzungsbedingungen und Robots-Regeln koennen sich aendern; fuer einzelne Jobboersen ist keine stabile oeffentliche API gesichert; OffeneRegister ist nicht amtlich und teilweise historisch. Diese Unsicherheiten muessen pro Quelle maschinenlesbar als Risiko und Review-Pflicht sichtbar bleiben.
  - [x] Schritte:
    1. Source-Schema erweitern und Migrationslogik bauen: Neue Pflichtfelder in `schemas/jobagent.schema.json` ergaenzen, bestehende Quellen in `data/jobagent/company-discovery.sources.json` verlustfrei migrieren und `review_required` fuer alle nicht-offiziellen oder ToS-unsicheren Quellen erzwingen.
    2. Quellklassifikation implementieren: In `src/JobAgent.CompanyInventory.psm1` eine Validierung erstellen, die `OFFICIAL_REGISTER`, `OPEN_REGISTER_DUMP`, `REGIONAL_DIRECTORY`, `JOB_BOARD_DISCOVERY`, `OFFICIAL_COMPANY`, `OFFICIAL_ATS` und `MANUAL_REVIEW` unterscheidet und nur offizielle Firmen-/Karrierequellen als Primaerbeleg akzeptiert.
    3. Coverage-/Audit-Ausgabe ergaenzen: In `src/JobAgent.Coverage.psm1` pro Quelle zaehlen, welche Kandidaten nur Discovery-Hinweis, welche rechtlich/recherchetechnisch blockiert und welche produktiv importierbar sind; HTML-/JSON-Report darf keine Vollstaendigkeit behaupten.
  - [x] Evidence: Aktualisierte `data/jobagent/company-discovery.sources.json`, Schema-Ausschnitt fuer Source Registry, `docs/company-discovery-source-contract.md`, Testlog `logs/jobagent/ja-023-source-registry-test.json`, Coverage-Audit mit Quellenklassen.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentSchema.ps1` -> Exit 0. Neue Testfaelle lehnen fehlendes `allowed_use` und Jobboerse als Primaerbeleg fail-closed ab.
  - [x] Audit: Manuell pruefen, dass jede aktive Quelle eine erlaubte und verbotene Nutzung nennt, dass StepStone/Indeed/Arbeitsagentur nur Discovery-Hinweise erzeugen, dass Unternehmensregister/Handelsregister nicht ohne dokumentiertes Limit massenhaft abgefragt werden und dass keine Secrets oder personenbezogenen Rollen gespeichert werden.
  - [x] Supertest: `.\\ci.cmd supertest` -> Exit 0.
  - [x] Meilenstein: M1 Source Registry v2 und Evidenzvertrag abgeschlossen; JA-024 bis JA-030 koennen auf fail-closed Quellenklassen aufsetzen.
## Archiviert am 2026-08-23

- [x] JA-023 Source Registry, Nutzungsgrenzen und Evidenzvertrag fuer massenhaftes Firmen-Discovery haerten #comment: Vor tausenden Kandidaten muessen Quellen, Erlaubnisgrenzen, Rollen und Nachweisfelder deterministisch sein, damit keine unzulaessigen oder unbelegten Firmen in den produktiven Store gelangen.
  - [x] Beschreibung: Es existiert eine versionierte Source Registry fuer mindestens diese Quellklassen: offizielle Registerportale, offene Handelsregister-Dumps, kommunale/regionale Wirtschaftslisten, Jobboersen als Arbeitgeber-Hinweise, Karriere-/ATS-Quellen als Primaerbelege und manuelle Review-Listen. Jede Quelle enthaelt `source_id`, `source_class`, `source_url`, `operator`, `allowed_use`, `forbidden_use`, `rate_limit_policy`, `robots_or_terms_note`, `expected_fields`, `evidence_level`, `freshness_policy`, `retention_policy`, `import_mode`, `review_required` und `legal_risk`. Bekannte Startquellen sind mindestens `https://www.unternehmensregister.de/`, `https://www.handelsregister.de/`, `https://offeneregister.de/daten/`, `https://www.stepstone.de/jobs/in-m%C3%BCnchen`, `https://www.stepstone.de/jobs/in-freising`, `https://www.arbeitsagentur.de/jobsuche/`, `https://de.indeed.com/`, kommunale/regionale Seiten fuer Muenchen und Freising sowie vorhandene interne Feeds unter `data/jobagent/`.
  - [x] Scope: Betroffen sind `data/jobagent/company-discovery.sources.json`, `schemas/jobagent.schema.json`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1` und neue Dokumentation `docs/company-discovery-source-contract.md`. No-Go: keine Umgehung von Login, Captcha, Robots-/Nutzungsgrenzen oder Abruflimits; keine Jobboerse als offizieller Primaernachweis; keine Aufnahme personenbezogener Registerrollen; keine automatisierte Massenabfrage offizieller Portale ohne explizites Rate-Limit.
  - [x] Ist-Stand (2026-08-23 10:00): Lokaler Store hat 38 Firmen und 38 Karrierequellen; `Roadmap.md` war auf 20 Firmen veraltet. Webrecherche zeigt als Kandidatenquellen: Unternehmensregister als zentrale Plattform fuer veroeffentlichungspflichtige Unternehmensdaten, Registerportal/Handelsregister fuer Registerdaten, OffeneRegister als nicht-offizieller Open-Data-Dump mit mehreren Millionen Firmen, StepStone-Muenchen mit ca. 9.753 bis 10.213 offenen Stellenanzeigen, sowie StepStone-Kategorien/Jobseiten mit Arbeitgebernamen. Diese Angaben sind Momentaufnahmen und muessen im Source-Contract als volatile Hinweise statt Vollstaendigkeitsbeweis behandelt werden.
  - [x] Abhängigkeiten: Keine technische Vorarbeit offen; dieser Punkt ist Grundlage fuer JA-024 bis JA-030.
  - [x] Aufwand/Dauer: Aufwand M, Dauer 1-2 PT bei 1 Entwickler/Agent; parallelisierbar nur fuer Dokumentation und Tests, nicht fuer Schemaentscheidung.
  - [x] Prioritätsscore: 100/100, weil saubere Quell- und Nutzungsgrenzen vor jeder massenhaften Erfassung zwingend sind.
  - [x] Ordnungsbegründung: Ohne Source Registry waeren nachgelagerte Importer nicht auditierbar und koennten unzulaessige oder falsch gewichtete Hinweise in den Store schreiben.
  - [x] Risiken und Unsicherheiten: Nutzungsbedingungen und Robots-Regeln koennen sich aendern; fuer einzelne Jobboersen ist keine stabile oeffentliche API gesichert; OffeneRegister ist nicht amtlich und teilweise historisch. Diese Unsicherheiten muessen pro Quelle maschinenlesbar als Risiko und Review-Pflicht sichtbar bleiben.
  - [x] Schritte:
    1. Source-Schema erweitern und Migrationslogik bauen: Neue Pflichtfelder in `schemas/jobagent.schema.json` ergaenzen, bestehende Quellen in `data/jobagent/company-discovery.sources.json` verlustfrei migrieren und `review_required` fuer alle nicht-offiziellen oder ToS-unsicheren Quellen erzwingen.
    2. Quellklassifikation implementieren: In `src/JobAgent.CompanyInventory.psm1` eine Validierung erstellen, die `OFFICIAL_REGISTER`, `OPEN_REGISTER_DUMP`, `REGIONAL_DIRECTORY`, `JOB_BOARD_DISCOVERY`, `OFFICIAL_COMPANY`, `OFFICIAL_ATS` und `MANUAL_REVIEW` unterscheidet und nur offizielle Firmen-/Karrierequellen als Primaerbeleg akzeptiert.
    3. Coverage-/Audit-Ausgabe ergaenzen: In `src/JobAgent.Coverage.psm1` pro Quelle zaehlen, welche Kandidaten nur Discovery-Hinweis, welche rechtlich/recherchetechnisch blockiert und welche produktiv importierbar sind; HTML-/JSON-Report darf keine Vollstaendigkeit behaupten.
  - [x] Evidence: Aktualisierte `data/jobagent/company-discovery.sources.json`, Schema-Ausschnitt fuer Source Registry, `docs/company-discovery-source-contract.md`, Testlog `logs/jobagent/ja-023-source-registry-test.json`, Coverage-Audit mit Quellenklassen.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentSchema.ps1` -> Exit 0. Neue Testfaelle lehnen fehlendes `allowed_use` und Jobboerse als Primaerbeleg fail-closed ab.
  - [x] Audit: Manuell pruefen, dass jede aktive Quelle eine erlaubte und verbotene Nutzung nennt, dass StepStone/Indeed/Arbeitsagentur nur Discovery-Hinweise erzeugen, dass Unternehmensregister/Handelsregister nicht ohne dokumentiertes Limit massenhaft abgefragt werden und dass keine Secrets oder personenbezogenen Rollen gespeichert werden.
  - [x] Supertest: `.\\ci.cmd supertest` -> Exit 0.
  - [x] Meilenstein: M1 Source Registry v2 und Evidenzvertrag abgeschlossen; JA-024 bis JA-030 koennen auf fail-closed Quellenklassen aufsetzen.
## Archiviert am 2026-08-23

- [x] JA-023 Source Registry, Nutzungsgrenzen und Evidenzvertrag fuer massenhaftes Firmen-Discovery haerten #comment: Vor tausenden Kandidaten muessen Quellen, Erlaubnisgrenzen, Rollen und Nachweisfelder deterministisch sein, damit keine unzulaessigen oder unbelegten Firmen in den produktiven Store gelangen.
  - [x] Beschreibung: Es existiert eine versionierte Source Registry fuer mindestens diese Quellklassen: offizielle Registerportale, offene Handelsregister-Dumps, kommunale/regionale Wirtschaftslisten, Jobboersen als Arbeitgeber-Hinweise, Karriere-/ATS-Quellen als Primaerbelege und manuelle Review-Listen. Jede Quelle enthaelt `source_id`, `source_class`, `source_url`, `operator`, `allowed_use`, `forbidden_use`, `rate_limit_policy`, `robots_or_terms_note`, `expected_fields`, `evidence_level`, `freshness_policy`, `retention_policy`, `import_mode`, `review_required` und `legal_risk`. Bekannte Startquellen sind mindestens `https://www.unternehmensregister.de/`, `https://www.handelsregister.de/`, `https://offeneregister.de/daten/`, `https://www.stepstone.de/jobs/in-m%C3%BCnchen`, `https://www.stepstone.de/jobs/in-freising`, `https://www.arbeitsagentur.de/jobsuche/`, `https://de.indeed.com/`, kommunale/regionale Seiten fuer Muenchen und Freising sowie vorhandene interne Feeds unter `data/jobagent/`.
  - [x] Scope: Betroffen sind `data/jobagent/company-discovery.sources.json`, `schemas/jobagent.schema.json`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tests/Test-JobAgentCompanyInventory.ps1`, `tests/Test-JobAgentCoverage.ps1` und neue Dokumentation `docs/company-discovery-source-contract.md`. No-Go: keine Umgehung von Login, Captcha, Robots-/Nutzungsgrenzen oder Abruflimits; keine Jobboerse als offizieller Primaernachweis; keine Aufnahme personenbezogener Registerrollen; keine automatisierte Massenabfrage offizieller Portale ohne explizites Rate-Limit.
  - [x] Ist-Stand (2026-08-23 10:00): Lokaler Store hat 38 Firmen und 38 Karrierequellen; `Roadmap.md` war auf 20 Firmen veraltet. Webrecherche zeigt als Kandidatenquellen: Unternehmensregister als zentrale Plattform fuer veroeffentlichungspflichtige Unternehmensdaten, Registerportal/Handelsregister fuer Registerdaten, OffeneRegister als nicht-offizieller Open-Data-Dump mit mehreren Millionen Firmen, StepStone-Muenchen mit ca. 9.753 bis 10.213 offenen Stellenanzeigen, sowie StepStone-Kategorien/Jobseiten mit Arbeitgebernamen. Diese Angaben sind Momentaufnahmen und muessen im Source-Contract als volatile Hinweise statt Vollstaendigkeitsbeweis behandelt werden.
  - [x] Abhängigkeiten: Keine technische Vorarbeit offen; dieser Punkt ist Grundlage fuer JA-024 bis JA-030.
  - [x] Aufwand/Dauer: Aufwand M, Dauer 1-2 PT bei 1 Entwickler/Agent; parallelisierbar nur fuer Dokumentation und Tests, nicht fuer Schemaentscheidung.
  - [x] Prioritätsscore: 100/100, weil saubere Quell- und Nutzungsgrenzen vor jeder massenhaften Erfassung zwingend sind.
  - [x] Ordnungsbegründung: Ohne Source Registry waeren nachgelagerte Importer nicht auditierbar und koennten unzulaessige oder falsch gewichtete Hinweise in den Store schreiben.
  - [x] Risiken und Unsicherheiten: Nutzungsbedingungen und Robots-Regeln koennen sich aendern; fuer einzelne Jobboersen ist keine stabile oeffentliche API gesichert; OffeneRegister ist nicht amtlich und teilweise historisch. Diese Unsicherheiten muessen pro Quelle maschinenlesbar als Risiko und Review-Pflicht sichtbar bleiben.
  - [x] Schritte:
    1. Source-Schema erweitern und Migrationslogik bauen: Neue Pflichtfelder in `schemas/jobagent.schema.json` ergaenzen, bestehende Quellen in `data/jobagent/company-discovery.sources.json` verlustfrei migrieren und `review_required` fuer alle nicht-offiziellen oder ToS-unsicheren Quellen erzwingen.
    2. Quellklassifikation implementieren: In `src/JobAgent.CompanyInventory.psm1` eine Validierung erstellen, die `OFFICIAL_REGISTER`, `OPEN_REGISTER_DUMP`, `REGIONAL_DIRECTORY`, `JOB_BOARD_DISCOVERY`, `OFFICIAL_COMPANY`, `OFFICIAL_ATS` und `MANUAL_REVIEW` unterscheidet und nur offizielle Firmen-/Karrierequellen als Primaerbeleg akzeptiert.
    3. Coverage-/Audit-Ausgabe ergaenzen: In `src/JobAgent.Coverage.psm1` pro Quelle zaehlen, welche Kandidaten nur Discovery-Hinweis, welche rechtlich/recherchetechnisch blockiert und welche produktiv importierbar sind; HTML-/JSON-Report darf keine Vollstaendigkeit behaupten.
  - [x] Evidence: Aktualisierte `data/jobagent/company-discovery.sources.json`, Schema-Ausschnitt fuer Source Registry, `docs/company-discovery-source-contract.md`, Testlog `logs/jobagent/ja-023-source-registry-test.json`, Coverage-Audit mit Quellenklassen.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\\Test-JobAgentSchema.ps1` -> Exit 0. Neue Testfaelle lehnen fehlendes `allowed_use` und Jobboerse als Primaerbeleg fail-closed ab.
  - [x] Audit: Manuell pruefen, dass jede aktive Quelle eine erlaubte und verbotene Nutzung nennt, dass StepStone/Indeed/Arbeitsagentur nur Discovery-Hinweise erzeugen, dass Unternehmensregister/Handelsregister nicht ohne dokumentiertes Limit massenhaft abgefragt werden und dass keine Secrets oder personenbezogenen Rollen gespeichert werden.
  - [x] Supertest: `.\\ci.cmd supertest` -> Exit 0.
  - [x] Meilenstein: M1 Source Registry v2 und Evidenzvertrag abgeschlossen; JA-024 bis JA-030 koennen auf fail-closed Quellenklassen aufsetzen.


## Archiviert am 2026-08-23

- [x] JA-024 Register- und Open-Data-Kandidatenimport fuer Muenchen/Freising aufbauen #comment: Die groesste Firmenbasis kommt aus Registerdaten; sie muss als Kandidatenbestand importiert werden, ohne amtliche Vollstaendigkeit oder Aktivitaet zu behaupten.
  - [x] Beschreibung: Es existiert eine deterministische Import-Lane, die grosse Registerdatenquellen in lokale Kandidaten-Hints fuer Muenchen, 20-km-Umkreis und Freising umwandelt. OffeneRegister-Dumps werden bevorzugt als bulk-faehige, nicht-amtliche Kandidatenquelle verarbeitet; offizielle Portale wie Unternehmensregister und Handelsregister dienen fuer gezielte Nachpruefung einzelner Kandidaten und nicht fuer ungebremstes Scraping. Kandidaten erhalten `register_name`, `register_city`, `register_court`, `register_number`, `legal_form`, `source_snapshot`, `source_freshness`, `target_area_match`, `confidence_score`, `review_status`, `official_verification_required` und `dedupe_keys`.
  - [x] Scope: Neu oder erweitert werden `tools/Import-JobAgentRegisterCandidates.ps1`, `src/JobAgent.RegisterDiscovery.psm1`, `data/jobagent/company-discovery.register.json`, `data/jobagent/company-discovery.hints.json`, `schemas/jobagent.schema.json`, `tests/Test-JobAgentRegisterDiscovery.ps1` und `docs/company-discovery-register-import.md`. No-Go: keine Speicherung von Geschaeftsfuehrer-/Gesellschafterdaten, keine Bonitaets-/Compliance-Bewertung, keine automatische Behauptung "aktiv" ohne Beleg, keine produktive Karrierequelle aus Registerdaten allein.
  - [x] Ist-Stand (2026-08-23 10:15): Registerimporter, Fixture-Daten, Output-Datei, Hint-Merge und Dokumentation sind implementiert. Der produktive Store bleibt unveraendert; Registerdaten erzeugen ausschliesslich unverifizierte Kandidaten-Hints mit offizieller Verifikationspflicht.
  - [x] Abhängigkeiten: JA-023 muss abgeschlossen sein; JA-027 nutzt die erzeugten Kandidaten fuer Deduplikation und Standortbewertung.
  - [x] Aufwand/Dauer: Aufwand M innerhalb der aktuellen Arbeitseinheit; umgesetzt fixture-first ohne Live-Download.
  - [x] Prioritätsscore: 96/100, weil Registerdaten die notwendige Groessenordnung von tausenden Firmen liefern.
  - [x] Ordnungsbegründung: Bulk-Kandidaten muessen vor Jobboersen-Hinweisen und Verifikation vorliegen, damit spaetere Quellen gegen eine breite Basis dedupliziert werden koennen.
  - [x] Risiken und Unsicherheiten: OffeneRegister-Daten koennen veraltet, nicht vollstaendig und nicht amtlich sein; offizielle Registerportale koennen Abruflimits haben; Firmen mit Sitz ausserhalb, aber Standort in Muenchen/Freising, fehlen in reinen Registerstadt-Filtern.
  - [x] Schritte:
    1. Fixture-first Parser bauen: Kleinen lokalen JSONL/CSV-Fixture-Dump mit Muenchen-, Freising-, Randgemeinde-, Dubletten-, geloeschten und unvollstaendigen Registereintraegen erstellen und Parser auf Streaming-Verarbeitung auslegen, damit grosse Dumps ohne komplettes Laden in den Speicher verarbeitet werden.
    2. Zielgebietsfilter implementieren: `Muenchen`, `München`, `Munich`, `Freising` und definierte Gemeinden im 20-km-Umkreis als Kandidatenfilter modellieren; unklare Orte als `TARGET_AREA_UNCERTAIN` statt Ausschluss markieren.
    3. Hints statt Firmen schreiben: Importer schreibt nur Discovery-Hints mit Register-Evidenz, Snapshot-ID, Hash, Zeilennummer/Record-ID und Review-Pflicht; produktive `companies` bleiben unveraendert, bis JA-028 offizielle Firmen-/Karrierebelege liefert.
  - [x] Evidence: `data/jobagent/company-discovery.register.json` oder generierte lokale Hint-Datei, Importlog mit Record-Zaehlern, Reject-Gründen und Hashes, Dokumentation der genutzten Registerquelle, Testfixture unter `tests/fixtures/jobagent/register-discovery/`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\\Test-JobAgentRegisterDiscovery.ps1` -> Exit 0; deckt JSONL/CSV, Zeichensatz, Ortsfilter, Dubletten, unvollstaendige Registerdaten, stale/future Snapshot-Metadaten und fail-closed Verhalten bei fehlender Source Registry ab.
  - [x] Audit: Registerdaten erzeugen nur `REGISTER_DISCOVERY_HINT`; Tests pruefen, dass keine personenbezogenen Registerrollen persistiert werden. Source Registry trennt offizielle Registerportale von Open-Register-Dumps; Importzahlen werden als Kandidaten-Hints und nicht als Marktdeckung ausgegeben.
  - [x] Supertest: `.\\ci.cmd supertest` -> Exit 0; `Test-JobAgentRegisterDiscovery.ps1` ist in Supertest und Testmatrix aufgenommen.
  - [x] Meilenstein: M2 Register-Kandidatenimport abgeschlossen; JA-027 kann die Register-Hints fuer skalierte Deduplikation nutzen.

## Archiviert am 2026-08-23

- [x] JA-025 Jobboersen-Arbeitgeberhinweise aus StepStone, Arbeitsagentur, Indeed und weiteren Quellen rechtssicher importieren #comment: Jobboersen liefern viele aktuelle Arbeitgebernamen, duerfen aber nur Discovery-Hinweise und keine offiziellen Karrierebelege erzeugen.
  - [x] Beschreibung: Es existiert eine Jobboersen-Discovery-Lane, die Arbeitgebernamen, Stellenort, Jobtitel, Anzeigen-URL, Plattform, Abrufzeitpunkt, Suchparameter, Seitennummer und Snapshot-Hash als Hinweise erfasst. StepStone-Muenchen und StepStone-Freising sind Startquellen; Indeed bleibt wegen `MANUAL_REVIEW_ONLY` fail-closed. Jeder Treffer bleibt `DISCOVERY_HINT` mit `job_board_discovery_status=JOB_BOARD_DISCOVERY` und verlangt offizielle Firmen-/Karriereverifikation vor produktiver Aufnahme.
  - [x] Scope: Neu erstellt wurden `tools/Import-JobAgentJobBoardEmployers.ps1`, `src/JobAgent.JobBoardDiscovery.psm1`, `data/jobagent/company-discovery.jobboards.json`, `tests/Test-JobAgentJobBoardDiscovery.ps1`, `docs/company-discovery-jobboards.md` und Fixtures unter `tests/fixtures/jobagent/jobboard-discovery/`. Erweitert wurden `data/jobagent/company-discovery.hints.json`, `tests/Test-JobAgentSupertest.ps1`, `tests/Test-JobAgentTestMatrix.ps1`, `docs/test-matrix.json` und `docs/test-matrix.md`. No-Go eingehalten: kein Login, kein Captcha-Bypass, keine verdeckte API-Nutzung, keine personenbezogenen Recruiter-Daten, keine Jobboerse als Primaerquelle, keine Anzeigenvolltexte.
  - [x] Ist-Stand (2026-08-23 10:25): Der Importer verarbeitet gespeicherte StepStone-Snapshots fixture-first, prueft Source-Registry-Policy, normalisiert Arbeitgebernamen, markiert Personaldienstleister, dedupliziert gleiche Arbeitgeberhinweise, schreibt minimale Hash-Evidenz und merged unverifizierte Hints in `data/jobagent/company-discovery.hints.json`. Der produktive Store und `job_sources` bleiben unveraendert.
  - [x] Abhängigkeiten: JA-023 und JA-024 sind abgeschlossen; JA-027 nutzt normalisierte Arbeitgebernamen und Dedupe-Keys; JA-028 verifiziert offizielle Quellen.
  - [x] Aufwand/Dauer: Aufwand M innerhalb der aktuellen Arbeitseinheit; umgesetzt als deterministische Snapshot-/Fixture-Lane ohne Live-Webabruf.
  - [x] Prioritätsscore: 90/100, weil Jobboersen aktuelle Arbeitgeber mit realer Einstellungsaktivitaet liefern und Registerdaten um Standort-/Niederlassungshinweise ergaenzen.
  - [x] Ordnungsbegründung: Nach Source Registry und Registerbasis werden Jobboersen-Hinweise importiert, um aktive Arbeitgeber zu priorisieren und Firmen ohne Muenchner Registersitz sichtbar zu machen.
  - [x] Risiken und Unsicherheiten: Jobboersen-Seiten sind volatil, koennen A/B-Markup, Bot-Schutz oder Terms-Einschraenkungen haben; Anzeigen koennen Personaldienstleister statt Einsatzunternehmen nennen; Duplikate ueber mehrere Plattformen sind wahrscheinlich. Live-Abrufe bleiben deshalb ausserhalb der Funktionstests blockiert.
  - [x] Schritte:
    1. Plattformneutralen Adaptervertrag implementiert: Eingabe `query`, `location`, `radius_km`, `page_limit`, `fetched_at`; Ausgabe `employer_name`, `job_title`, `job_location`, `posting_url`, `platform`, `source_record_hash`, `evidence_snippet_hash`, `confidence_score`, `raw_retention_policy`.
    2. StepStone-Fixture und Source-Policy getrennt: HTML-Fixtures fuer Muenchen/Freising testen; Indeed/Manual-Review-only bleibt fail-closed; Live-Abruf erfolgt nicht in Funktionstests.
    3. Hint-Merge implementiert: Arbeitgebernamen werden gegen bekannte Firmen normalisiert, Personaldienstleister markiert, gleiche Arbeitgeber ueber Seiten zusammengefuehrt und alle Kandidaten mit `official_verification_required=true` gespeichert.
  - [x] Evidence: `data/jobagent/company-discovery.jobboards.json`, `data/jobagent/company-discovery.hints.json`, `logs/jobagent/company-discovery-jobboards-import-20260823-082216.json`, Fixtures unter `tests/fixtures/jobagent/jobboard-discovery/`, Dokumentation `docs/company-discovery-jobboards.md`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentJobBoardDiscovery.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
  - [x] Audit: Jobboersen-URLs landen nur als `observed_url`/`posting_url` in unverifizierten Hints, nicht als offizielle Bewerbungslinks oder JobSources. Snapshots speichern minimale Testdaten; Produktivimport speichert nur Hashes und Metadaten. Plattformen mit unklarer Zugriffslage bleiben blockiert.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0; `Test-JobAgentJobBoardDiscovery.ps1` ist in Supertest und Testmatrix aufgenommen.
  - [x] Meilenstein: M3 Jobboersen-Hinweisimport abgeschlossen; JA-027 kann Deduplikation und Standortlogik gegen Register- und Jobboersen-Hints skalieren.
- [x] JA-026 Regionale Branchen-, Kommunal- und Arbeitgeberlisten fuer Muenchen/Freising importieren #comment: Register und Jobboersen reichen nicht aus, weil Niederlassungen, Hochschulen, Kliniken, Verwaltungen, Mittelstand und Clusterlisten eigene Quellen brauchen.
  - [x] Beschreibung: Es existiert eine Import-Lane fuer regionale Quellen wie Stadt/Landkreis Muenchen, Stadt/Landkreis Freising, IHK-/Wirtschaftsfoerderungslisten, Cluster-/Startup-Verzeichnisse, Hochschulen/Forschungseinrichtungen, Kliniken/Pflege-/Traegerlisten, Flughafen-/Logistikumfeld und Gewerbegebiet-/Branchenverzeichnisse. Jede Quelle wird als `REGIONAL_DIRECTORY` oder `PUBLIC_INSTITUTION_DIRECTORY` erfasst und erzeugt Kandidaten mit `region_reference`, `sector_hint`, `address_or_location_hint`, `source_page`, `observed_at`, `officialness_level`, `manual_review_reason` und `priority_score`.
  - [x] Scope: Neu oder erweitert wurden `tools/Import-JobAgentRegionalDirectories.ps1`, `src/JobAgent.RegionalDiscovery.psm1`, `data/jobagent/company-discovery.regional-hints.json`, `tests/Test-JobAgentRegionalDiscovery.ps1`, `docs/company-discovery-regional-directories.md`, `src/JobAgent.Coverage.psm1`, `tests/Test-JobAgentCoverage.ps1`, Supertest und Testmatrix. No-Go eingehalten: keine gekauften oder loginpflichtigen Listen, keine E-Mail-/Telefon-Sammlung, keine Branchenbuchdaten als offizielle Karrierequelle.
  - [x] Ist-Stand (2026-08-23 10:42): Regionale Import-Lane ist implementiert; der bestehende verifizierte Feed `data/jobagent/company-discovery.regional.json` bleibt fuer offizielle Discovery-Importe reserviert, unverifizierte regionale Hinweise werden in `data/jobagent/company-discovery.regional-hints.json` geschrieben und in `data/jobagent/company-discovery.hints.json` gemergt.
  - [x] Abhängigkeiten: JA-023, JA-024 und JA-025 sind abgeschlossen; JA-027 und JA-028 verarbeiten die regionalen Kandidaten weiter.
  - [x] Aufwand/Dauer: Aufwand L, umgesetzt in einem fokussierten Agentenlauf mit deterministischen Fixtures.
  - [x] Prioritätsscore: 84/100, weil regionale Listen Luecken schliessen, die weder Registerstadt noch Jobboersen vollstaendig abdecken.
  - [x] Ordnungsbegründung: Nach Register- und Jobboersenbasis wurden regionale Speziallisten als eigene Hint-Lane erfasst, ohne den offiziellen Firmenfeed zu ersetzen.
  - [x] Risiken und Unsicherheiten: Regionale Listen bleiben selektiv, koennen veralten und belegen keine offiziellen Karrierequellen; Vollstaendigkeit fuer alle Muenchner/Freisinger Firmen ist weiterhin nicht gesichert.
  - [x] Schritte:
    1. Quellenvertrag umgesetzt: `REGIONAL_DIRECTORY` und `PUBLIC_INSTITUTION_DIRECTORY` werden fail-closed gegen Source Registry, Importmodus und Evidenzlevel geprueft.
    2. Parser umgesetzt: Tabellen-HTML, Karten-HTML und JSON-Snapshots werden getrennt verarbeitet; blockierte Quellen und fehlende Namen schlagen kontrolliert fehl oder werden gezaehlt.
    3. Priorisierung und Merge umgesetzt: regionale Hints erhalten Zielgebiet, Sektor, Review-Grund, Prioritaet, Hash-Evidenz und werden in den allgemeinen Hint-Store gemergt; Coverage und Importwelle D kennen regionale Hints.
  - [x] Evidence: `src/JobAgent.RegionalDiscovery.psm1`, `tools/Import-JobAgentRegionalDirectories.ps1`, `data/jobagent/company-discovery.regional-hints.json`, `docs/company-discovery-regional-directories.md`, `tests/fixtures/jobagent/regional-discovery/`, `logs/jobagent/company-discovery-regional-import-20260823-084238.json`.
  - [x] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentRegionalDiscovery.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1` -> Exit 0; `pwsh -NoProfile -File tests\Test-JobAgentTestMatrix.ps1` -> Exit 0.
  - [x] Audit: Tests sichern regionale Listen als selektive, unverifizierte Kandidatenquellen; Kontaktfelder werden nicht persistiert; Muenchen/Freising/20-km/unsichere Orte werden unterscheidbar; bestehender offizieller Regionalfeed bleibt getrennt.
  - [x] Supertest: `.\ci.cmd supertest` -> Exit 0.
