# Roadmap

Stand: 2026-09-15. JA-027 ist archiviert: Die Viewport-Audit-Lane nutzt nun die lokale Playwright-CLI statt des lokal instabilen Chrome-Headless-GPU-Pfads; Fixture- und produktiver Coverage-Report wurden bei 390/800/1366/1920 px erzeugt. Nutzerkorrektur: berufsneutrale Basis und Filter statt Firmenwellen als Roadmap-Ziel. Verbindliche Review-Basis der übrigen Punkte: [Webreview](docs/reviews/2026-09-05-webreview.md), [Messwerte](docs/reviews/2026-09-05-baseline.json). Historische Importfortschritte stehen vollständig im [vorherigen Plan](docs/reviews/2026-09-13-ja027-roadmap-before.md); UI-001 behält seine ID.

## Ziel, Annahmen und Messvertrag

- Ziel: Beim regulaeren Jobstart neue Firmen mit Website und offiziell belegter Jobs-/Karriere-/Stellenangebote-Unterseite oder ATS im Raum Muenchen/Freising dauerhaft aufnehmen und im WebIF anzeigen. Firmenbasis und Stellenerfassung sind berufsneutral; Berufe werden anschliessend ueber Filter gesucht. Roadmap-Punkte liefern diese Softwarefunktion, keine manuellen Firmenabfragewellen. Die bisherigen 1.000 Arbeitgeber sind nur ein Beobachtungswert, kein Start-, Release- oder Abschlussgate.
- Ist (2026-09-13, lokaler Bestand): 487 Firmen, 439 JobSources, 2.312 dauerhafte Discovery-Funde, 1.401 URL-Funde und 1.833 Hints. Queue: 1.131 Website-Reviewfaelle, 1 sonstiger Review, 23 Retry-Scheduled, 1 Retry-Exhausted, 675 VERIFIED. Diese Zaehler sind keine Zahl gueltiger eindeutiger Karrierearbeitgeber oder vollstaendiger Live-Scans; diese beiden Zielmengen vor dem Umsetzungslauf neu berechnen. Baseline: `docs/reviews/2026-09-13-ja027-acquisition-baseline.json`.
- Zählvertrag: getrennt ausweisen `discovered`, `official_source_verified`, `live_attempted`, `live_complete`, `partial`, `blocked`, `no_matching_job` und `matching_jobs`. Keine reale Firmenmindestmenge blockiert den Softwareabschluss; Firmen-, Karrierequellen- und Scanmenge getrennt messen. Kein Nulltreffer ohne vollständig abgearbeitete relevante Ergebnislisten/Seiten. Aktualitätsfenster zunächst 7 Tage als Planannahme; abweichende Quellenfristen gelten vorrangig.
- Kapazität: ein Entwickler/Agent, Windows/PowerShell 7.4+, lokaler JSON-Store und HTML-Berichte, keine zusätzliche Infrastruktur zugesagt. Verbleibende Planungsschätzung aus JA-041, UI-001 und JA-042: 7,5–11,5 Personentage, ungefähr 1,5–2,5 Arbeitswochen bei fünf Arbeitstagen pro Woche und acht Nettoarbeitsstunden pro Tag. Kein gemessener Durchsatz; externe Netzlaufzeit, manuelle Identitätsfälle und Zugangsgrenzen zusätzlich. Ein verbindlicher Termin und zusätzliche Teamkapazität fehlen.
- Gebiet: München, bestehender München-20-km-Bereich und Freising; Freising Stadt und Landkreis künftig getrennt. Ein Standort des Arbeitgebers beweist nicht den Standort einer Stelle. Remote/Hybrid nur bei belegtem Zielgebietsbezug; unbekannte Orte nicht automatisch passend.
- Reihenfolge: JA-027 ist abgeschlossen; JA-041 entkoppelt Stellenerfassung von Berufsprofilen; UI-001 liefert vollstaendige Filter; JA-042 sichert wiederholbaren Betrieb. Die Firmenbasisansicht ist durch JA-027 belegt.
- Grenzen: keine erfundenen Firmen, Stellen, URLs, IDs oder Vollständigkeitsnachweise; keine Bewerbungen/Nachrichten; keine Umgehung von Captcha/Login oder Quellenlimits. Jobbörsen, Register und weitere Sekundärquellen liefern Firmen-/URL-Hinweise; offizielle Firmen-/ATS-Quellen liefern Verifikationsbelege. Alle erfassten Firmen und entdeckten Firmenwebsite-/Karriere-/Jobs-/Stellenangebote-/ATS-URLs bleiben dauerhaft mit Herkunft und Prüfstatus gespeichert, auch ohne aktuelle Stellen oder erfolgreiche Verifikation. Keine automatische Löschung durch Refresh, Ablauf oder Abruffehler. Produktiver Store-Upsert erfolgt atomar und mit Backup.

## Meilensteine und priorisierte Punkte

M1: vorhandene Grundlagen JA-040/CI-001. M2-A: Akquise beim Jobstart und sichtbare Firmenbasis (JA-027, archiviert). M2-B: berufsneutrale Stellenbasis (JA-041). M3: Filtersuche und laufender Betrieb (UI-001/JA-042). Genau drei detaillierte Unterpunkte je Punkt, je drei Umsetzungsschritte. Ein zusammenhaengender Softwareschnitt je Punkt; keine manuellen 100er-/1.000er-Firmenwellen als Done-Gate.

- [ ] JA-041 Berufsneutrale Stellenerfassung von Suchprofilen trennen #comment: Regionale Daten automatisch sammeln und berufsneutral filtern statt manuell Firmenwellen abarbeiten.

  Beschreibung: Berufsneutrale Stellenerfassung von Suchprofilen trennen. Abnahme ueber drei funktionale Unterpunkte, keine reale Firmenquote.
  Ist-Stand (2026-09-13): tools/Invoke-JobAgentDailyRun.ps1 setzt SearchTerms auf Head of IT, Director IT, IT Leitung, IT-Leitung, Leiter IT und CIO. Programmvertrag/Klassifikation sind auf IT-Fuehrung zugeschnitten. Gelieferte Parser-/Paginationarbeit bleibt erhalten; MSG bleibt offener Einzelfall, keine Voraussetzung fuer alle anderen Berufe.
  Abhaengigkeiten: JA-040 und vorhandene offizielle Quellen; neue Firmen aus JA-027. Keine Mengenabhaengigkeit.
  Aufwand/Dauer: 3–5 PT / 3–5 Arbeitstage; ein Entwickler/Agent, acht Nettoarbeitsstunden pro PT; externe Wartezeit UNKNOWN. Kein verbindlicher Termin oder weitere Kapazitaet zugesagt.
  Prioritaetsscore: 98/100, Planungsentscheidung. Ordnungsbegruendung: neutrale Attribute vor allgemeinen Filtern.
  Risiken: implizite Altfilter, fehlende Attribute, partielle Quellen und veraltete Anzeige. UNKNOWN sichtbar erhalten. Meilenstein/Parallelisierung: M2-B; ein zusammenhaengender Slice, Fixtures bei zusaetzlicher Kapazitaet parallel, produktive Writer seriell.

  - [x] JA-041.1 Erfassung ohne impliziten Berufsfilter als Standard liefern.

    Beschreibung: Auch Buchhaltung, Pflege, Handwerk, Vertrieb und Ausbildung werden bei belegter regionaler Stelle gesammelt; IT-Fuehrung ist nur ein optionales Suchprofil.
    Scope: tools/Invoke-JobAgentDailyRun.ps1; src/JobAgent.LiveScan.psm1; schemas/jobagent.schema.json; manual/PROGRAM.md; docs/data-model.md; tests/Test-JobAgentLiveScan.ps1. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-15): Standardlauf und Live-Policy verwenden leere Suchbegriffe als `ALL_ROLES`; es gibt keinen IT-Fallback. Allgemeine Avature- und SuccessFactors-Listen werden ohne Rollenquery abgefragt. Als `REQUIRED` markierte Quellabfragen liefern ohne Scope `PARTIAL` mit expliziter Vollstaendigkeitsgrenze. Explizite Begriffe bleiben kompatibel als `EXPLICIT_TERMS`.
    Abhaengigkeiten/Prioritaet: Hauptpunkt-Grundlagen; Score 100/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M2-B. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Daily-SearchTerms und Live-Policy auf berufsneutralen Standard umstellen: leere Begriffe bedeuten alle Berufe, nicht die alte IT-Fallbackliste. Explizite CLI-/Profilbegriffe kompatibel als eingeschraenkten Suchscope dokumentieren. Alle impliziten IT-Vorselektionen zwischen Start, Request und Normalisierung verfolgen und entfernen.
    2. Offizielle allgemeine Joblisten/Feeds ohne Berufsfilter verwenden. Quelle mit zwingendem Suchterm und ohne allgemeine Liste als eingeschraenkt/PARTIAL dokumentieren, nicht als vollstaendig leer. Pagination, Timeout und Resultatlimits weiterhin sichtbar begrenzen. Kein Filter im WebIF veraendert diesen Erfassungsauftrag.
    3. manual/PROGRAM.md und Datenvertrag nach ausdruecklicher Nutzerkorrektur synchronisieren: Berufsprofil steuert Anzeige, nicht Firmenakquise. Muenchen mit bestehendem 20-km-Bereich und Freising beibehalten; Firmenstandort und Stellenort getrennt. Kein pauschaler Bayern-/Deutschland-Match; UNKNOWN explizit.
    Evidence/Done: `logs/jobagent/JA-041-1-acceptance.json` dokumentiert Gitstand, Fixture-IDs, Commands, Exitcodes und Soll-/Istzaehler. Allgemeine Buchhaltungs-, Pflege-, Avature- und SuccessFactors-Fixtures sowie die negative termpflichtige Quelle sind nachgewiesen; keine sichtbare UI-Aenderung, daher UI-Lane nicht anwendbar.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1 # Exit 0
    pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1 # Exit 0
    pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1 # Exit 0
    pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1 # Exit 0
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

  - [ ] JA-041.2 Gueltigkeit und Gebiet von persoenlicher Profilpassung trennen.

    Beschreibung: Eine echte Pflege- oder Buchhaltungsstelle darf nicht wegen fehlender IT-Fuehrung aus der allgemeinen Basis verschwinden. Nicht-Stellen und unbelegte Quellen bleiben ausgeschlossen.
    Scope: src/JobAgent.Classification.psm1; src/JobAgent.DailyRun.psm1; src/JobAgent.Persistence.psm1; src/JobAgent.StatusMachine.psm1; schemas/jobagent.schema.json. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: JA-041.1; Score 99/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M2-B. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Entscheidungen fuer offizielle Stellengueltigkeit, Region und optionale Profilpassung trennen. REJECTED nicht pauschal umwerten: Navigation/FAQ/News bleibt ungueltig; echte belegte Stelle mit fehlender IT-Verantwortung ist lediglich fuer das optionale Profil unpassend. Bestehende API-/Statusvertraege additiv migrieren.
    2. Berufsneutrale Attribute erhalten: Titel, Arbeitgeber, Stellenort, Arbeitsmodell, Anstellungsart, Arbeitszeit, Datumsfelder und offizielle URL. Fehlende Angaben UNKNOWN; Kategorie nur aus nachvollziehbaren Quellinformationen. Profilscore als abgeleitete Ansicht speichern, niemals als Speichervoraussetzung.
    3. Altbestand mit Backup idempotent neu bewerten, soweit offizielle Roh-/Detaildaten vorhanden sind; sonst regulaeren Recheck planen. Keine verlorenen Stellen erfinden oder historische first_seen umschreiben. Profilwechsel erzeugt kein NEW/CLOSED/REMOVED; Statusaenderung bleibt vom echten Quellscan abhaengig.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/JA-041-2-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/JA-041-2-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentClassification.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

  - [ ] JA-041.3 Berufsneutrale Pipeline durchgaengig verifizieren.

    Beschreibung: Allgemeine Erfassung liefert mehrere Berufe; optionales Profil reduziert nur die Anzeige, nicht gespeicherte Job-IDs oder Historie.
    Scope: tests/Test-JobAgentDailyRun.ps1; tests/Test-JobAgentClassification.ps1; tests/Test-JobAgentReport.ps1; docs/data-model.md. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: JA-041.2; Score 98/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 20 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M2-B. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Isolierte Fixtures fuer IT-Leitung, Buchhaltung, Pflege, Ausbildung und Nicht-Stellenseite jeweils mit Muenchen, Freising, ausserhalb und UNKNOWN anlegen. Erwartete IDs/Attribute festschreiben: echte regionale Stellen bleiben im Bestand, Nicht-Stelle ausgeschlossen, unklarer Ort getrennt.
    2. Allgemeine Ansicht und optionales IT-Profil auf identischen Store anwenden. Wiederholung, Profilwechsel, Teilscan und Fehler pruefen: identischer gespeicherter Bestand ohne falsche NEW-/REMOVED-Ereignisse. Filtertrefferzahl und gesamte Erfassungsmenge getrennt behaupten.
    3. Runmanifest mit Suchscope, Vollstaendigkeitsgrenzen und Testresultaten liefern. Bestehende Parser-Fixtures wiederverwenden; offene MSG-/ATS-Einzelfehler nur in diesen Slice aufnehmen, falls sie die neue allgemeine Pipeline nachweislich blockieren. Keine vollstaendige ATS-Neuentwicklung als Abschlussvoraussetzung.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/JA-041-3-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/JA-041-3-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

- [ ] UI-001 Berufsneutrale Firmen- und Stellensuche mit vollstaendigen Filtern bereitstellen #comment: Regionale Daten automatisch sammeln und berufsneutral filtern statt manuell Firmenwellen abarbeiten.

  Beschreibung: Berufsneutrale Firmen- und Stellensuche mit vollstaendigen Filtern bereitstellen. Abnahme ueber drei funktionale Unterpunkte, keine reale Firmenquote.
  Ist-Stand (2026-09-13): Review vom 2026-09-05 dokumentiert 250er-Firmenlimit, fehlende Filter/Pagination und widerspruechliche Badges. Historische Beobachtung, kein neuer Browserbefund; aktuellen Stand vor Umsetzung gegen Screens pruefen.
  Abhaengigkeiten: Grundlegende Firmenansicht aus JA-027, allgemeine Stellenattribute aus JA-041. UI-Fixtures ab stabilem Schema parallel moeglich.
  Aufwand/Dauer: 3–4 PT / 3–4 Arbeitstage; ein Entwickler/Agent, acht Nettoarbeitsstunden pro PT; externe Wartezeit UNKNOWN. Kein verbindlicher Termin oder weitere Kapazitaet zugesagt.
  Prioritaetsscore: 96/100, Planungsentscheidung. Ordnungsbegruendung: Filter bauen auf allgemeiner Datenbasis auf; Firmenbasisansicht bereits JA-027.
  Risiken: implizite Altfilter, fehlende Attribute, partielle Quellen und veraltete Anzeige. UNKNOWN sichtbar erhalten. Meilenstein/Parallelisierung: M3; ein zusammenhaengender Slice, Fixtures bei zusaetzlicher Kapazitaet parallel, produktive Writer seriell.

  Screenshot-Referenz: `doc/roadmap-screenshots/UI-001-review-20260905-coverage-1920.png`, `doc/roadmap-screenshots/UI-001-review-20260905-coverage-1366.png`, `doc/roadmap-screenshots/UI-001-review-20260905-coverage-800.png`, `doc/roadmap-screenshots/UI-001-review-20260905-coverage-390.png`; `doc/roadmap-screenshots/UI-001-review-20260905-daily-fixture-1920.png`, `doc/roadmap-screenshots/UI-001-review-20260905-daily-fixture-1366.png`, `doc/roadmap-screenshots/UI-001-review-20260905-daily-fixture-800.png`, `doc/roadmap-screenshots/UI-001-review-20260905-daily-fixture-390.png`; `doc/roadmap-screenshots/UI-001-review-20260905-status-conflict.png`. Bindend: fehlende Filter, Statuswiderspruch und horizontales Scrollen für wesentliche Jobfelder. Frühere nicht verfügbare Chatbilder werden nicht als vorhanden ausgegeben.

  - [ ] UI-001.1 Gemeinsamen Einstieg fuer Firmen und Stellen liefern.

    Beschreibung: WebIF auf 8500 zeigt Firmen und Stellen getrennt; keine IT-Rolle als versteckter Default. Firmen ohne offene Stellen bleiben sichtbar.
    Scope: src/JobAgent.Report.psm1; tools/Measure-JobAgentCompanyCoverage.ps1; html/jobagent/. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: Hauptpunkt-Grundlagen; Score 100/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M3. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Bestehende HTML-Berichte unter gemeinsamem Einstieg verbinden; aktualisierte Firmenbasis aus regulaerem Start nutzen. Firmenname/Ort/Website/Karrierelink und Jobtitel/Arbeitgeber/Stellenort/offizieller Stellenlink zuerst, interne IDs in Diagnosebereich.
    2. Gesamtbestand, gefilterte Treffer und sichtbare Seite getrennt zaehlen. Alle Firmen/Stellen ueber Pagination erreichbar machen, kein 250er-Limit. Akquise-/Scanresultate automatisch aus Startintegration uebernehmen, kein manueller Reportcommand. Keine neue Frontendplattform als Selbstzweck.
    3. Importdatum, letzte erfolgreiche Pruefung und Anzeigezeit getrennt halten. Name-only, Domain-only, offizielle Karrierequelle eindeutig beschriften; Abruffehler nicht als keine Stellen ausgeben. Fixtureartefakte sichtbar als Testdaten kennzeichnen.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/UI-001-1-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/UI-001-1-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

  - [ ] UI-001.2 Uebliche Filter lokal auf den gesamten Bestand anwenden.

    Beschreibung: Beliebige Berufe per Freitext sowie Ort, Arbeitgeber, Arbeitsmodell, Anstellungsart, Arbeitszeit und Aktualitaet suchen; IT-Fuehrung nur optional.
    Scope: src/JobAgent.Report.psm1; tools/Measure-JobAgentCompanyCoverage.ps1; bestehende HTML-/Reporttests. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: UI-001.1; Score 99/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M3. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Freitext Unicode-normalisieren und ohne Gross-/Kleinschreibung auswerten: mehrere Woerter UND, jedes Wort in Titel/Firma/belegter Berufskategorie suchbar. Kein Anzeigenvolltextversprechen bei fehlendem Volltext. Unterschiedliche Filterfelder UND, Mehrfachauswahl im selben Feld ODER; leere Auswahl bedeutet keine Einschraenkung.
    2. Gebietsfilter Muenchen/Stadt, bestehenden 20-km-Umkreis und Freising mit belegter Stadt-/Landkreiszuordnung getrennt fuehren; keinen neuen Freising-Radius erfinden. Stellenort statt Firmensitz nutzen. Remote/Hybrid nur mit belegtem Zielgebietsbezug, UNKNOWN ausdruecklich waehlbar. Fehlende Filterattribute nicht durch erfundene Defaultwerte ersetzen.
    3. Erst gesamten Bestand filtern, dann stabil nach Titel/Firma/Ort/Pruefdatum plus ID als Tie-Breaker sortieren und paginieren. Filterwechsel setzt Seite 1, Reset setzt Alle Berufe und keine Zusatzfilter. Ruecknavigation erhaelt Zustand. Kein Filterwechsel startet HTTP, Akquise, Joblauf oder Storemutation.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/UI-001-2-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/UI-001-2-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

  - [ ] UI-001.3 Filterkombinationen und Bedienung im echten Browser abnehmen.

    Beschreibung: Alle Daten erreichbar, exakte Trefferzahlen und bedienbare Ansichten auf Desktop/Mobil; reine HTML-Stringassertions genuegen nicht.
    Scope: tests/Test-JobAgentHtmlAudit.ps1; tests/Test-JobAgentHtmlViewportAudit.ps1; doc/roadmap-screenshots/. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: UI-001.2; Score 98/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 20 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M3. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Fixture mit mehr als 250 Firmen und mehreren Berufen nutzen. Erwartete IDs fuer Firma hinter 250, Freising+Pflege, Muenchen+Buchhaltung, Teilzeit+Hybrid, UNKNOWN, Umlautsuche und Nulltreffer festschreiben. Nach Filterwechsel gespeicherte Firmen/Jobs unveraendert.
    2. Pagination, Sortierung, Filterkombination, Reset und Ruecknavigation interaktiv testen. Fake Clock fuer Aktualitaetsgrenzen, Zeitzone/Mitternacht und fehlendes Pruefdatum; Browserprotokoll mit exakten Zaehler-/ID-Assertions sichern.
    3. 390/800/1366/1920 px pruefen: keine ueberlappenden Controls, kein Clipping wesentlicher Titel/Links, sichtbarer Fokus und Labels, verstaendliche Leerzustaende. Touch-Targets mindestens 44 px als Projektziel; Screens mit Fixturekennzeichnung. Server nur ci.cmd devserver-start auf 8500.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/UI-001-3-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/UI-001-3-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1
    ~~~
    Audit: Automatischer ID-/Status-/Mengenabgleich; bei sichtbaren Aenderungen echter Browser in 390/800/1366/1920 px, kein Clipping/Overlap, lesbare Kernfelder, korrekte Zaehler. Ohne Darstellungsänderung UI-Lane begruendet nicht anwendbar; keine Android-Lane.
    Supertest: Erst nach allen drei Unterpunkten und gruenen Funktionstests .\ci.cmd supertest; kein eigener Supertest/Miniabschluss pro Unterpunkt. Danach vollstaendige Archivierung des Softwarepunkts, Todo/Handoff und STP synchronisieren. Dieser Planungsauftrag fuehrt ihn nicht aus.

- [ ] JA-042 Wiederholbaren Jobstart mit Akquise und WebIF-Publikation absichern #comment: Regionale Daten automatisch sammeln und berufsneutral filtern statt manuell Firmenwellen abarbeiten.

  Beschreibung: Wiederholbaren Jobstart mit Akquise und WebIF-Publikation absichern. Abnahme ueber drei funktionale Unterpunkte, keine reale Firmenquote.
  Ist-Stand (2026-09-13): ManagedDailyRun bietet Lock-/Status-/Reportvertraege. Neue Kombination aus Akquise, allgemeiner Stellenerfassung und Filteransicht noch nicht implementiert oder abgenommen. Historische Live-Stichproben ersetzen diesen Nachweis nicht.
  Abhaengigkeiten: JA-027, JA-041 und UI-001 fuer integrierte Abnahme; bestehende JA-040/CI-001-Grundlagen. Keine reale 1.000er-Menge.
  Aufwand/Dauer: 1,5–2,5 PT / 1,5–2,5 Arbeitstage; ein Entwickler/Agent, acht Nettoarbeitsstunden pro PT; externe Wartezeit UNKNOWN. Kein verbindlicher Termin oder weitere Kapazitaet zugesagt.
  Prioritaetsscore: 94/100, Planungsentscheidung. Ordnungsbegruendung: integrierte Betriebsabnahme nach den drei Funktionsvertraegen.
  Risiken: implizite Altfilter, fehlende Attribute, partielle Quellen und veraltete Anzeige. UNKNOWN sichtbar erhalten. Meilenstein/Parallelisierung: M3; ein zusammenhaengender Slice, Fixtures bei zusaetzlicher Kapazitaet parallel, produktive Writer seriell.

  - [ ] JA-042.1 Phasen unter einem regulaeren Start verbinden.

    Beschreibung: Ein Start erledigt Akquise, allgemeine Stellenerfassung und WebIF-Publikation innerhalb getrennter Budgets.
    Scope: tools/Invoke-JobAgentDailyRun.ps1; src/JobAgent.Operations.psm1; src/JobAgent.DailyRun.psm1; tools/Get-JobAgentDailyRunStatus.ps1. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
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

