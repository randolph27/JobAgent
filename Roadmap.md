# Roadmap

Stand: 2026-09-15. JA-027, JA-041 und UI-001 sind archiviert. Die berufsneutrale Firmen- und Stellensuche ist mit Pagination, lokalen Kombinationsfiltern und Browserabnahme bei 390/800/1366/1920 px belegt. Verbindliche Review-Basis des verbleibenden Punkts: [Webreview](docs/reviews/2026-09-05-webreview.md), [Messwerte](docs/reviews/2026-09-05-baseline.json). Historische Importfortschritte stehen vollständig im [vorherigen Plan](docs/reviews/2026-09-13-ja027-roadmap-before.md).

## Ziel, Annahmen und Messvertrag

- Ziel: Beim regulaeren Jobstart neue Firmen mit Website und offiziell belegter Jobs-/Karriere-/Stellenangebote-Unterseite oder ATS im Raum Muenchen/Freising dauerhaft aufnehmen und im WebIF anzeigen. Firmenbasis und Stellenerfassung sind berufsneutral; Berufe werden anschliessend ueber Filter gesucht. Roadmap-Punkte liefern diese Softwarefunktion, keine manuellen Firmenabfragewellen. Die bisherigen 1.000 Arbeitgeber sind nur ein Beobachtungswert, kein Start-, Release- oder Abschlussgate.
- Ist (2026-09-13, lokaler Bestand): 487 Firmen, 439 JobSources, 2.312 dauerhafte Discovery-Funde, 1.401 URL-Funde und 1.833 Hints. Queue: 1.131 Website-Reviewfaelle, 1 sonstiger Review, 23 Retry-Scheduled, 1 Retry-Exhausted, 675 VERIFIED. Diese Zaehler sind keine Zahl gueltiger eindeutiger Karrierearbeitgeber oder vollstaendiger Live-Scans; diese beiden Zielmengen vor dem Umsetzungslauf neu berechnen. Baseline: `docs/reviews/2026-09-13-ja027-acquisition-baseline.json`.
- Zählvertrag: getrennt ausweisen `discovered`, `official_source_verified`, `live_attempted`, `live_complete`, `partial`, `blocked`, `no_matching_job` und `matching_jobs`. Keine reale Firmenmindestmenge blockiert den Softwareabschluss; Firmen-, Karrierequellen- und Scanmenge getrennt messen. Kein Nulltreffer ohne vollständig abgearbeitete relevante Ergebnislisten/Seiten. Aktualitätsfenster zunächst 7 Tage als Planannahme; abweichende Quellenfristen gelten vorrangig.
- Kapazität: ein Entwickler/Agent, Windows/PowerShell 7.4+, lokaler JSON-Store und HTML-Berichte, keine zusätzliche Infrastruktur zugesagt. Verbleibende Planungsschätzung für JA-042: 1,5–2,5 Personentage, ungefähr 1,5–2,5 Arbeitstage bei fünf Arbeitstagen pro Woche und acht Nettoarbeitsstunden pro Tag. Kein gemessener Durchsatz; externe Netzlaufzeit, manuelle Identitätsfälle und Zugangsgrenzen zusätzlich. Ein verbindlicher Termin und zusätzliche Teamkapazität fehlen.
- Gebiet: München, bestehender München-20-km-Bereich und Freising; Freising Stadt und Landkreis künftig getrennt. Ein Standort des Arbeitgebers beweist nicht den Standort einer Stelle. Remote/Hybrid nur bei belegtem Zielgebietsbezug; unbekannte Orte nicht automatisch passend.
- Reihenfolge: JA-027, JA-041 und UI-001 sind abgeschlossen; JA-042 sichert den wiederholbaren Betrieb. Die Firmenbasisansicht, die berufsneutrale Stellenbasis und die vollständige Filteransicht sind belegt.
- Grenzen: keine erfundenen Firmen, Stellen, URLs, IDs oder Vollständigkeitsnachweise; keine Bewerbungen/Nachrichten; keine Umgehung von Captcha/Login oder Quellenlimits. Jobbörsen, Register und weitere Sekundärquellen liefern Firmen-/URL-Hinweise; offizielle Firmen-/ATS-Quellen liefern Verifikationsbelege. Alle erfassten Firmen und entdeckten Firmenwebsite-/Karriere-/Jobs-/Stellenangebote-/ATS-URLs bleiben dauerhaft mit Herkunft und Prüfstatus gespeichert, auch ohne aktuelle Stellen oder erfolgreiche Verifikation. Keine automatische Löschung durch Refresh, Ablauf oder Abruffehler. Produktiver Store-Upsert erfolgt atomar und mit Backup.

## Meilensteine und priorisierte Punkte

M1: vorhandene Grundlagen JA-040/CI-001. M2-A: Akquise beim Jobstart und sichtbare Firmenbasis (JA-027, archiviert). M2-B: berufsneutrale Stellenbasis (JA-041, archiviert). M3: Filtersuche (UI-001, archiviert) und laufender Betrieb (JA-042). Genau drei detaillierte Unterpunkte je Punkt, je drei Umsetzungsschritte. Ein zusammenhaengender Softwareschnitt je Punkt; keine manuellen 100er-/1.000er-Firmenwellen als Done-Gate.

- [ ] JA-042 Wiederholbaren Jobstart mit Akquise und WebIF-Publikation absichern #comment: Regionale Daten automatisch sammeln und berufsneutral filtern statt manuell Firmenwellen abarbeiten.

  Beschreibung: Wiederholbaren Jobstart mit Akquise und WebIF-Publikation absichern. Abnahme ueber drei funktionale Unterpunkte, keine reale Firmenquote.
  Ist-Stand (2026-09-15): JA-042.1 ist mit gemeinsamer Daily-Run-ID, getrennten Akquise-/Scanbudgets, atomarem Status-Pointer und Teilfehler-Isolation abgenommen. Offen bleiben Resume-/Dublettenbeweis (JA-042.2) und der integrierte Skalierungs-/Betriebsabschluss (JA-042.3).
  Abhaengigkeiten: JA-027, JA-041 und UI-001 fuer integrierte Abnahme; bestehende JA-040/CI-001-Grundlagen. Keine reale 1.000er-Menge.
  Aufwand/Dauer: 1,5–2,5 PT / 1,5–2,5 Arbeitstage; ein Entwickler/Agent, acht Nettoarbeitsstunden pro PT; externe Wartezeit UNKNOWN. Kein verbindlicher Termin oder weitere Kapazitaet zugesagt.
  Prioritaetsscore: 94/100, Planungsentscheidung. Ordnungsbegruendung: integrierte Betriebsabnahme nach den drei Funktionsvertraegen.
  Risiken: implizite Altfilter, fehlende Attribute, partielle Quellen und veraltete Anzeige. UNKNOWN sichtbar erhalten. Meilenstein/Parallelisierung: M3; ein zusammenhaengender Slice, Fixtures bei zusaetzlicher Kapazitaet parallel, produktive Writer seriell.

  - [x] JA-042.1 Phasen unter einem regulaeren Start verbinden.

    Beschreibung: Ein Start erledigt Akquise, allgemeine Stellenerfassung und WebIF-Publikation innerhalb getrennter Budgets.
    Scope: tools/Invoke-JobAgentDailyRun.ps1; src/JobAgent.Operations.psm1; src/JobAgent.DailyRun.psm1; tools/Get-JobAgentDailyRunStatus.ps1. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-15): Unter einer `dailyrun:`-ID verbindet der bestehende Einstieg Akquise und allgemeinen Scan. Akquise-Phasen werden bei Teilfehlern als `PARTIAL` weitergefuehrt; der Scan bleibt lauffaehig. Die Statusdatei ist der atomare Publikations-Pointer und erhaelt den letzten Report bei Neuberechnung oder Fehler als veralteten Stand. Nachweis: `logs/jobagent/JA-042-1-acceptance.json`.
    Abhaengigkeiten/Prioritaet: Hauptpunkt-Grundlagen; Score 100/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M3. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Unter gemeinsamer Run-ID validieren, budgetierte Akquise starten, Quellen uebergeben, allgemein scannen, Report atomar publizieren und Abschlussstatus schreiben. Bestehenden Benutzereinstieg erhalten; kein manueller Import-/Verify-/Reportbefehl im Normalbetrieb.
    2. Globale/Hostlimits und separate Akquise-/Scanbudgets verifizieren. Doppelstart darf keinen zweiten Writer erzeugen. Ausfallende Quelle/Retry blockiert keine anderen Firmen; Storefehler stoppt schreibende Folgearbeit sicher. Lauf bleibt zeitlich begrenzt.
    3. WebIF meldet laeuft/abgeschlossen/teilweise/fehlgeschlagen mit Zeit und lesbarem Grund. Vorherige Daten waehrend Neuberechnung/Fehler erhalten und als alten Stand markieren. Keine Terminalrueckfragen oder ungefragt eingerichteten OS-Schedulerjobs.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/JA-042-1-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/JA-042-1-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

  - [ ] JA-042.2 Resume und Wiederholung ohne Verlust oder Dubletten nachweisen.

    Beschreibung: Naechster Benutzerstart setzt faellige Arbeit fort; bekannte Firmen und Stellen werden nicht neu dupliziert.
    Scope: src/JobAgent.Persistence.psm1; src/JobAgent.StatusMachine.psm1; src/JobAgent.Operations.psm1; vorhandene Queue/Checkpoints. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: JA-042.1; Score 99/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M3. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Abbruch vor/nach Resultatsicherung, Storecommit und Reportpublikation mit isolierten Fixtures erzwingen. Wiederanlauf verwendet Cursor/Resultate; uebernommene Firma nicht erneut als neu zaehlen. Alte Firmen-/URL-Funde bleiben auch nach abgelaufener Verifikation erhalten.
    2. Zukuenftige Retries/Retry-After respektieren, wake_at ausgeben und Lauf beenden statt Busy-Wait. Neue Evidence reaktiviert nur betroffene Cluster. Gleicher Snapshot/gleiche Evidence erzeugt keine unnoetige erneute Neufirmenakquise.
    3. Stellenstatus bei vollstaendigem, eingeschraenktem und partiellem Scan pruefen. Nur komplette relevante Quellabdeckung darf Abwesenheit begruenden; im WebIF weggefilterte Stelle bleibt aktiv gespeichert. Keine falschen NEW/CLOSED/REMOVED beim Profilwechsel.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/JA-042-2-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/JA-042-2-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

  - [ ] JA-042.3 Integrierten Softwareabschluss ohne manuelle Mengenwellen liefern.

    Beschreibung: Abnahme misst automatische Startfunktion und Wiederholung; reales Wachstum entsteht in spaeteren Joblaeufen des Nutzers.
    Scope: tests/Test-JobAgentCompanyDedupeScale.ps1; tests/Test-JobAgentDailyRun.ps1; tests/Test-JobAgentReport.ps1; docs/company-discovery-operations.md. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: JA-042.2; Score 98/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 20 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M3. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. 1.000 isolierte Fixturefirmen mit Dubletten, Domain-only, verschiedenen Berufen, Quellenfehlern und Gebietsgrenzen testen. Endliche Budgets, vollstaendige Hostwellen und Cursorfortsetzung nachweisen. Keine 1.000 realen Firmen zum Abarbeiten des Punkts abfragen.
    2. Zwei regulaere Starts mit kontrollierter Evidence: zuerst neue Firma samt Website/Karrierelink und mehreren Berufen; danach bekannte Firma unveraendert plus genau eine neue. Erwartete IDs/Zaehler und WebIF-Filterresultate exakt abgleichen. Fixture- und Produktivbestand strikt getrennt.
    3. Betriebsdokumentation mit Runcommand, Reportpfad, Budgetgrenzen und Resumeanleitung synchronisieren. Keine ungemessene Durchsatzgarantie/ETA. Nach gruenen Funktionstests und Browserabnahme Supertest, Roadmap-/Todo-/Handoff-Sync und STP zusammen abschliessen; reales Firmenwachstum danach im normalen Betrieb.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/JA-042-3-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/JA-042-3-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

