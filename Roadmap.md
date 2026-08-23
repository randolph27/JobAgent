# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das Firmeninventar enthaelt erst 20 Arbeitgeber; Vollstaendigkeit ist unbelegt. Die Recherchequellen fuer Muenchen, 20-km-Umkreis und Freising sind noch nicht als deterministische Source Registry, Import-Lane, Verifikations-Lane und Coverage-Audit operationalisiert.
- Priorisierung: Zuerst muessen Quellenkategorien und Evidenzvertrag stabil sein, danach werden offizielle regionale Listen und oeffentliche Jobdaten als Discovery-Hinweise importiert, anschliessend werden Karriere-URLs/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store breit erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- [ ] JA-027 Firmen-Coverage-Audit und priorisierte Importwellen fuer maximale Abdeckung einfuehren #comment: Nach Quellen- und Verifikationsaufbau braucht der JobAgent messbare Abdeckung nach Region, Branche, Quelle und Reviewstatus, damit die Liste systematisch waechst.
  - [ ] Beschreibung: Der JobAgent erzeugt einen Coverage-Audit fuer Firmeninventar und Discovery-Backlog mit Zielwerten je Welle; Importwellen priorisieren offizielle/verifizierte Arbeitgeber aus grossen IT-relevanten Branchen, Grossarbeitgebern, oeffentlichem Sektor, Hochschulen/Forschung, Flughafen/Freising, Startups/Scaleups und Dienstleistern, bis alle Kandidaten mit Website und Karriere-/Jobs-Seite entweder importiert, dedupliziert oder begruendet verworfen sind.
  - [ ] Scope: Neu/zu aendern sind `src/JobAgent.Coverage.psm1`, `tools/Measure-JobAgentCompanyCoverage.ps1`, `logs/jobagent/company-coverage-*.json`, `html/jobagent/company-coverage.html`, `tests/Test-JobAgentCoverage.ps1` und optional `tests/Test-JobAgentHtmlAudit.ps1` fuer den HTML-Bericht. No-Go: keine Vollstaendigkeitsbehauptung ohne dokumentierten Nenner; keine nicht verifizierten Kandidaten in `CAREER_URL_VERIFIED`; keine HTML-Report-Abhaengigkeit von externen Runtime-Ressourcen.
  - [ ] Ist-Stand (2026-08-23 07:45): Coverage-Backlog existiert, aber kein messbarer Nenner fuer Quellenklassen, Branchen, Zielgebiete, Importwellen und Reviewstatus. Der HTML-Audit fuer Berichte ist mit JA-022 vorhanden und kann fuer Coverage-Artefakte wiederverwendet werden.
  - [ ] Abhängigkeiten: Abhaengig von JA-023 fuer Quellenkatalog; sinnvoll nach mindestens einer Importwelle aus JA-024 und optional Hint-Backlog aus JA-025.
  - [ ] Aufwand/Dauer: Aufwand M; Annahme 1 Entwickler/Agent, 1 Arbeitstag fuer Metriken, Report, Tests und initiale Zielwerte ohne manuelle Firmenrecherche.
  - [ ] Prioritätsscore: 86/100, weil hohe Abdeckung ohne auditierbare Metriken nicht steuerbar ist und spaetere Chats sonst wieder punktuell Firmen ergaenzen.
  - [ ] Ordnungsbegründung: Nach Import- und Verifikationspfad wird die Skalierung messbar gemacht; dadurch werden weitere Wellen nach Wert/Risiko statt Bauchgefuehl priorisiert.
  - [ ] Risiken und Unsicherheiten: Ein echter Vollstaendigkeitsnenner ist fuer Muenchen/Freising nicht gesichert; private Quellen koennen unvollstaendig sein; kleinere Unternehmen haben haeufig keine eigene Jobseite; Startups wechseln Domains oder Hiring-Seiten oft.
  - [ ] Schritte:
    1. Coverage-Metriken definieren: Firmen im Store, `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED`, `UNVERIFIED`, `MANUAL_REVIEW`, Dubletten, Quelle je Firma, Zielgebiet, Branche, Arbeitgebergroesse falls vorhanden, letztes Reviewdatum und naechste Importwelle.
    2. Importwellenplan implementieren: Welle A boersennotierte/grosse regionale Arbeitgeber, Welle B Freising/Weihenstephan/Flughafen-Umfeld, Welle C EMM-Mitglieder und Branchencluster, Welle D BA/EURES/Make-it-in-Germany-Hints, Welle E Startup-/Scaleup-Cluster und manuelle Review-Reste.
    3. JSON-/Markdown-/HTML-Coverage-Bericht erzeugen, der konkrete naechste Kandidatenlisten ausgibt, aber keine unverifizierten Fakten als Firmenbestand ausweist.
  - [ ] Evidence: `logs/jobagent/company-coverage-<timestamp>.json`, `logs/jobagent/company-coverage-<timestamp>.md`, `html/jobagent/company-coverage.html`, Coverage-Screenshot falls HTML-Audit erweitert wird.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1`; falls HTML erzeugt wird zusaetzlich `pwsh -NoProfile -File tests\Test-JobAgentHtmlAudit.ps1`.
  - [ ] Audit: Bericht bei 1920/1366/800 px pruefen, keine Tabellenueberlaeufe ohne horizontales Scrollen, keine externen Ressourcen, keine Secrets; inhaltlich pruefen, dass `UNKNOWN` und `UNVERIFIED` sichtbar bleiben und Vollstaendigkeit nur als Coverage-Quote ueber bekannte Quellen, nicht als Marktbehauptung, dargestellt wird.
  - [ ] Supertest: `pwsh -NoProfile -File tests\Test-JobAgentSupertest.ps1` erst nach gruenem Coverage-Funktionstest und optionalem HTML-Audit.
  - [ ] Meilenstein: M5 messbare Firmenabdeckung; parallelisierbar mit weiteren Importwellen, sobald JA-024 bis JA-026 stabile Artefakte liefern.
