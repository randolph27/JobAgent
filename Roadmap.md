# Roadmap

## Annahmen und Priorisierungslogik

- Kapazitätsannahme: 1 Entwickler/Agent, lokale Windows-Umgebung `D:\_Scripte\JobAgent`, App läuft nur lokal, Daily-Runs zunächst manuell oder über lokale Automatisierung, kein externer Schreibzugriff auf Bewerbungs- oder Unternehmenssysteme.
- Projektgröße: PowerShell-Modulstack mit JSON-Store, CI-Vertrag, Funktions- und Supertest-Lane; keine Web-UI als Produktivserver, aber lokale HTML-Berichtsartefakte sind fachlich erforderlich.
- Review-Basis: Implementierung bis JA-022 ist weitgehend fachlich angelegt. Gesichert vorhanden sind Persistenz, Firmen-Seed, offizieller Quellenbeleg, Discovery-Import, Fixture-/generischer HTML-/Live-Adapter, Klassifikation, Deduplikation, Statusmaschine, Daily-Run, JSON-/Markdown-/HTML-Report, Betriebsstatus, Coverage-Backlog, lokaler HTML-Audit und Supertest-Lane.
- Kritische Lücken: Das produktive Firmeninventar enthaelt aktuell nur 38 Arbeitgeber. Fuer das Ziel "alle Muenchner und Freisinger Firmen" fehlt eine skalierbare Kandidatenbasis aus Register-, Regional- und Jobboersenquellen; Vollstaendigkeit, Lizenz-/Nutzungsgrenzen, Deduplikation, Standortbezug und offizielle Karriereverifikation sind noch nicht belastbar operationalisiert.
- Priorisierung: Zuerst muessen Quellenrecht, Source Registry, Rate-Limits und Evidenzvertrag stabil sein, danach werden massentaugliche Register-/Regional-/Jobboersen-Hinweise importiert, anschliessend werden Kandidaten dedupliziert und standortbezogen bewertet, danach werden offizielle Firmen-/Karriere-/ATS-Belege automatisiert verifiziert und erst dann wird der produktive Store in Wellen auf tausende Firmen erweitert.
- No-Go über alle Punkte: keine erfundenen Unternehmen, Stellen, URLs, Job-IDs, Geodaten, Gehälter oder Verifikationsaussagen; Jobbörsen nur zur Entdeckung, nicht als Primärnachweis; keine Bewerbung; keine extern wirksame Aktion ohne ausdrückliche Bestätigung; keine Secrets in Reports, Logs, Todo, Handoff oder Git.

## Aktive Punkte

- [ ] JA-036 Begrenzte offizielle Verifikationswelle aus der Kandidaten-Queue ausfuehren #comment: Der produktive Store darf erst wachsen, wenn Top-Kandidaten ueber offizielle Firmen-, Karriere- oder ATS-Belege fail-closed verifiziert wurden.
  - [ ] Beschreibung: Eine begrenzte Verifikationswelle verarbeitet die priorisierten Top-Kandidaten aus JA-035, prueft offizielle Website-, Karriere- und ATS-Belege im erlaubten Umfang und schreibt nur bei belastbarer Evidenz `CAREER_URL_VERIFIED`, `COMPANY_DOMAIN_VERIFIED` oder `OFFICIAL_ATS_VERIFIED`. Alle anderen Kandidaten bleiben mit maschinenlesbarem Grund in Retry, Manual Review oder Reject; Jobboersenlinks werden nie zu offiziellen Anbieterlinks.
  - [ ] Scope: Betroffen sind voraussichtlich `tools/Verify-JobAgentCompanyCandidates.ps1`, `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.LiveScan.psm1`, `src/JobAgent.CompanyInventory.psm1`, `data/jobagent/company-candidate-verification.queue.json`, `logs/jobagent/company-candidate-verification-*.json`, `tests/Test-JobAgentCompanyCandidateVerification.ps1`, `tests/Test-JobAgentSourceVerification.ps1` und `tests/Test-JobAgentLiveScan.ps1`. No-Go: keine Bewerbungen, kein Formular-Autofill, kein Login/Captcha, keine globale ATS-Allowlist ohne Firmenbeleg, keine Uebernahme ungesicherter Aggregator-URLs.
  - [ ] Ist-Stand (2026-08-24 09:05): Technische Verifikationslogik existiert aus JA-028, aber es gibt keinen neuen aktiven Punkt fuer eine konkrete begrenzte Welle auf aktuellen, priorisierten Kandidaten. Die Zahl der verarbeitbaren Kandidaten ist erst nach JA-034/JA-035 bekannt.
  - [ ] Abhängigkeiten: JA-034 und JA-035 muessen abgeschlossen oder mit belastbaren Fixture-/Snapshot-Artefakten verifizierbar sein; Source Registry muss jede Live-Quelle erlauben.
  - [ ] Aufwand/Dauer: Aufwand L, Dauer 2-3 PT bei 1 Entwickler/Agent; Fixture-Funktionstests koennen parallel zur Live-Wellenplanung laufen, Live-Ausfuehrung und Audit nicht.
  - [ ] Prioritätsscore: 78/100, weil Verifikation hohen Produktwert hat, aber erst nach Snapshot und Review-Queue fachlich sicher ist.
  - [ ] Ordnungsbegründung: Offizielle Verifikation ist das Gate vor produktiver Erweiterung und darf nicht vor priorisierter Kandidatensteuerung starten.
  - [ ] Risiken und Unsicherheiten: Webseiten koennen JavaScript-only, blockiert, mehrdeutig oder nicht erreichbar sein; Suchergebnisse koennen falsche Domains liefern. Unsichere Faelle muessen fail-closed bleiben und duerfen den Store nicht veraendern.
  - [ ] Schritte:
    1. Wellenlimit festlegen: Maximalzahl, Rate-Limits, Timeout, Retry-Regeln und erlaubte Quellen aus Registry und Queue ableiten.
    2. Verifikation ausfuehren: Top-Kandidaten pruefen, Redirect-Ketten, Evidence-Hashes, Statuscodes, finale URLs und Gruende protokollieren.
    3. Produktive Writes absichern: Nur offiziell verifizierte Kandidaten upserten; vor jedem Store-Write Backup und Gate-Report erzeugen.
    4. Tests und Audit erweitern: Positive und negative Verifikationspfade, ATS mit/ohne Firmenbeleg, Redirects, Timeout, 404 und Review-Pfade testen.
  - [ ] Evidence: `logs/jobagent/company-candidate-verification-*.json`, Store-Backup unter `data/jobagent/backups/`, aktualisierte Queue mit Verifikationsstatus, Coverage-Delta-Bericht, Testlogs der Verifikations- und LiveScan-Tests.
  - [ ] Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentCompanyCandidateVerification.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentSourceVerification.ps1`; `pwsh -NoProfile -File tests\Test-JobAgentLiveScan.ps1`; bei Store-Write zusaetzlich `pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1`.
  - [ ] Audit: Stichprobenartig pruefen, dass jede produktiv uebernommene Firma eine offizielle Evidence-URL hat, dass Jobboersen nicht als offizielle Links erscheinen und dass Reports keine externe Erreichbarkeit ueber den belegten Pruefzeitpunkt hinaus behaupten.
  - [ ] Supertest: `.\\ci.cmd supertest` erst nach gruenen Funktionstests; falls nicht ausdruecklich angefragt, gilt er gemaess Nutzeranweisung als erledigt.
  - [ ] Meilenstein: M8.3 Offizielle Verifikationswelle; nicht sinnvoll parallel zur finalen JA-035-Queue-Abnahme.

