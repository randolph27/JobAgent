# Roadmap

Stand: 2026-09-13. Akquiseplan nach lokaler Baseline neu priorisiert; JA-027.1 ist als Retention-Schnitt umgesetzt. Neu: Der regulaere Daily-Run startet bei vorhandenem Hint-Store automatisch eine budgetierte Akquisephase und scannt neu verifizierte Karrierearbeitgeber im selben Lauf; JA-027.2 ist geschlossen; in JA-027.3 sind Domain-only-Reaktivierung, Hostwellenplanung ohne Kandidatenverlust und getrennte Domain-only-/Karriere-Metriken umgesetzt. JA-027 bleibt offen, weil die abschliessende Viewport-Audit-Lane durch lokalen Chrome-GPU-Abbruch blockiert ist. Nutzerkorrektur: berufsneutrale Basis und Filter statt Firmenwellen als Roadmap-Ziel. Verbindliche Review-Basis der übrigen Punkte: [Webreview](docs/reviews/2026-09-05-webreview.md), [Messwerte](docs/reviews/2026-09-05-baseline.json). Historische Importfortschritte stehen vollständig im [vorherigen Plan](docs/reviews/2026-09-05-roadmap-before.md); JA-027 und UI-001 bleiben offen und behalten ihre IDs.

## Ziel, Annahmen und Messvertrag

- Ziel: Beim regulaeren Jobstart neue Firmen mit Website und offiziell belegter Jobs-/Karriere-/Stellenangebote-Unterseite oder ATS im Raum Muenchen/Freising dauerhaft aufnehmen und im WebIF anzeigen. Firmenbasis und Stellenerfassung sind berufsneutral; Berufe werden anschliessend ueber Filter gesucht. Roadmap-Punkte liefern diese Softwarefunktion, keine manuellen Firmenabfragewellen. Die bisherigen 1.000 Arbeitgeber sind nur ein Beobachtungswert, kein Start-, Release- oder Abschlussgate.
- Ist (2026-09-13, lokaler Bestand): 487 Firmen, 439 JobSources, 2.312 dauerhafte Discovery-Funde, 1.401 URL-Funde und 1.833 Hints. Queue: 1.131 Website-Reviewfaelle, 1 sonstiger Review, 23 Retry-Scheduled, 1 Retry-Exhausted, 675 VERIFIED. Diese Zaehler sind keine Zahl gueltiger eindeutiger Karrierearbeitgeber oder vollstaendiger Live-Scans; diese beiden Zielmengen vor dem Umsetzungslauf neu berechnen. Baseline: `docs/reviews/2026-09-13-ja027-acquisition-baseline.json`.
- Zählvertrag: getrennt ausweisen `discovered`, `official_source_verified`, `live_attempted`, `live_complete`, `partial`, `blocked`, `no_matching_job` und `matching_jobs`. Keine reale Firmenmindestmenge blockiert den Softwareabschluss; Firmen-, Karrierequellen- und Scanmenge getrennt messen. Kein Nulltreffer ohne vollständig abgearbeitete relevante Ergebnislisten/Seiten. Aktualitätsfenster zunächst 7 Tage als Planannahme; abweichende Quellenfristen gelten vorrangig.
- Kapazität: ein Entwickler/Agent, Windows/PowerShell 7.4+, lokaler JSON-Store und HTML-Berichte, keine zusätzliche Infrastruktur zugesagt. Verbleibende Planungsschätzung aus JA-027, JA-041, UI-001 und JA-042: 13,5–21 Personentage, ungefähr 3–5 Arbeitswochen bei fünf Arbeitstagen pro Woche und acht Nettoarbeitsstunden pro Tag. Kein gemessener Durchsatz; externe Netzlaufzeit, manuelle Identitätsfälle und Zugangsgrenzen zusätzlich. Ein verbindlicher Termin und zusätzliche Teamkapazität fehlen.
- Gebiet: München, bestehender München-20-km-Bereich und Freising; Freising Stadt und Landkreis künftig getrennt. Ein Standort des Arbeitgebers beweist nicht den Standort einer Stelle. Remote/Hybrid nur bei belegtem Zielgebietsbezug; unbekannte Orte nicht automatisch passend.
- Reihenfolge: JA-027 liefert Akquise beim regulaeren Jobstart inklusive sichtbarer Firmenliste; JA-041 entkoppelt Stellenerfassung von Berufsprofilen; UI-001 liefert vollstaendige Filter; JA-042 sichert wiederholbaren Betrieb. Grundlegende Firmenanzeige ist bereits JA-027-Pflicht.
- Grenzen: keine erfundenen Firmen, Stellen, URLs, IDs oder Vollständigkeitsnachweise; keine Bewerbungen/Nachrichten; keine Umgehung von Captcha/Login oder Quellenlimits. Jobbörsen, Register und weitere Sekundärquellen liefern Firmen-/URL-Hinweise; offizielle Firmen-/ATS-Quellen liefern Verifikationsbelege. Alle erfassten Firmen und entdeckten Firmenwebsite-/Karriere-/Jobs-/Stellenangebote-/ATS-URLs bleiben dauerhaft mit Herkunft und Prüfstatus gespeichert, auch ohne aktuelle Stellen oder erfolgreiche Verifikation. Keine automatische Löschung durch Refresh, Ablauf oder Abruffehler. Produktiver Store-Upsert erfolgt atomar und mit Backup.

## Meilensteine und priorisierte Punkte

M1: vorhandene Grundlagen JA-040/CI-001. M2-A: Akquise beim Jobstart und sichtbare Firmenbasis (JA-027). M2-B: berufsneutrale Stellenbasis (JA-041). M3: Filtersuche und laufender Betrieb (UI-001/JA-042). Genau drei detaillierte Unterpunkte je Punkt, je drei Umsetzungsschritte. Ein zusammenhaengender Softwareschnitt je Punkt; keine manuellen 100er-/1.000er-Firmenwellen als Done-Gate. Dieser Auftrag bleibt Planung mit STP/Git-Abschluss, ohne Implementierung oder Supertest.

- [ ] JA-027 Automatische Firmenakquise beim regulaeren Jobstart mit sichtbarem WebIF-Bestand liefern #comment: Quellenzufuhr und Karriereverifikation in einem wiederaufnehmbaren Lauf verbinden; Fortschritt an neuen belegten Arbeitgebern statt an Reparatur- oder Importwellen messen.

  Beschreibung: Den bereits implementierten Speicher-, Verifikations-, Resume- und HTTP-Vertrag weiterverwenden und die unterbrochene Kette Quelle → Firmen-/URL-Hinweis → belegte Website → belegte Karriere-/ATS-Quelle schliessen. Der bestehende regulaere Einstieg tools/Invoke-JobAgentDailyRun.ps1 startet ohne zusaetzlichen Akquisebefehl einen budgetierten Discovery-/Verifikationsabschnitt und publiziert die Firmenansicht. Akquise funktioniert ohne Berufssuchbegriff oder passende offene Stelle. Ein interner Orchestrator darf kein neuer Bedienzwang werden. Abnahme erfolgt am getesteten Verhalten, nicht an einer realen Firmenquote.

  Ist-Stand (2026-09-13 10:15 Europe/Berlin): Lokaler Store: 487 companies, 439 job_sources, 2.312 discovery_inventory, 1.401 discovered_urls. Hint-Store: 1.833 Hints; gespeicherte Queue: 1.831 Eintraege, davon 1.131 MANUAL_REVIEW_REQUIRED/DISCOVER_OFFICIAL_WEBSITE, 1 MANUAL_DECISION, 1 RETRY_EXHAUSTED, 14 Website-Retries, 9 Verify-Retries und 675 VERIFIED/ALREADY_VERIFIED_IN_STORE. Die 23 Retryeintraege sind noch kein neu berechneter Ready-Bestand. Der dokumentierte Batch 20260907-111932 brachte bei 17 Kandidaten acht domainverifizierte Firmen, aber null neue Karrierequellen. Neu (2026-09-13): `tools/Invoke-JobAgentDailyRun.ps1` fuehrt vor dem Scan automatisch eine budgetierte Akquisephase aus, wenn ein Hint-Store existiert; verifizierte neue Karrierearbeitgeber werden in `src/JobAgent.DailyRun.psm1` im selben Lauf in die Scan-Auswahl aufgenommen und im HTML-Report als neues Unternehmen mit Website/Karrierequelle sichtbar. Evidence: `logs/jobagent/JA-027-regular-start-acquisition.json`. RegionalDiscovery uebertraegt noch keinen allgemeinen website_hint-/career_hint-Vertrag. Dies begruendet die verbleibende Engpasshypothese fehlender Zufuehrung/Weiterverarbeitung; eine numerische Beschleunigung ist bisher nicht gemessen. Baseline mit Inputhashes: `docs/reviews/2026-09-13-ja027-acquisition-baseline.json`. Historische Zahlen und saemtliche frueheren JA-027-Schritte unveraendert: `docs/reviews/2026-09-13-ja027-roadmap-before.md`; bei Abweichungen gilt fuer den aktuellen Bestand die neue lokale Baseline, nicht ein alter Coverage-Report.

  Scope: Bestehende PowerShell-/JSON-Architektur und die unten genannten Dateien. Kein Framework-/Datenbankwechsel, grundlegende Firmenanzeige im WebIF als Pflichtumfang, umfassende Stellenfilter in UI-001, keine Stellenadapter-Nebenbaustelle und keine Neuerstellung bereits gelieferter TLS-/Resume-/Retention-Funktionen. Quellenbudgets, Identitaetspruefung und dauerhafte Speicherung bleiben verbindlich. Keine Nachrichten/Bewerbungen, bezahlten Zugangsabschluesse oder Umgehung von Login/Captcha; keine geratene Domain als Verifikationsbeleg.

  Abhaengigkeiten: JA-040 und CI-001 archiviert; vorhandene Retention aus JA-027.1 als Regression absichern, danach JA-027.2 und JA-027.3 zusammenhaengend abschliessen. JA-041 ist keine Akquisevoraussetzung. Der offene MSG-Adapterfall bleibt dort dokumentiert und wartet bei nur einer Arbeitskapazitaet hinter diesem Akquise-Hotspot; weder als erledigt markieren noch hier reparieren.

  Aufwand/Dauer: Verbleibende Planungsschaetzung 6–9,5 PT bei einem Entwickler/Agent und acht Nettoarbeitsstunden pro PT; 6–10 Arbeitstage Implementierung/Verifikation, externe Quellenklaerung und Livewartezeit zusaetzlich UNKNOWN. Groesse: vorhandener lokaler Bestand laut Baseline, Skalierungsfixture 1.000 Firmen, keine reale Mindestquote; kein linearer Hochrechnungsbeleg. Teamzuwachs, bezahlte Daten und verbindlicher Liefertermin fehlen. Keine externe Arbeitgebermindestmenge als Abnahmekriterium. Bei Umsetzung manual/PROGRAM.md mit der ausdruecklichen Nutzerkorrektur vom 2026-09-13 synchronisieren: dessen IT-Fuehrungsprofil ist ueberholt; README bleibt unberuehrt.

  Prioritaetsscore: 99/100 als Planungsentscheidung, kein gemessener Businesswert. Ordnungsbegruendung: Bestehende Grundlagen nutzen, zuerst den Eingang mit verwertbaren URLs versorgen, dann Domain-only-Luecke und Hostwellen schliessen, zuletzt Menge belegen. Groesserer Workerpool allein behebt weder fehlende Websites noch null Karrierequellenzuwachs. Risiken: unzulaessige/veraltete Snapshots, Namenskollisionen, fehlender Gebietsbezug, Quellenlimits, geringe Ausbeute und konkurrierende Writer.

  Meilenstein/Parallelisierung: M2-A = pruefbarer, nachfuellbarer Eingang (JA-027.1/.2); M2-A-Abnahme = automatische Verifikation beim regulaeren Start und Firmenanzeige (JA-027.3). Genau drei detaillierte Unterpunkte, keine neuen Top-Level-Todos. Ein zusammenhaengender Umsetzungsschnitt mit funktionsbezogenen Tests, Roadmap-/Todo-/Handoff-Sync und STP; technische Teilproben innerhalb dieses Schnitts. Falls echte externe Blockade: Bestand und Cursor sichern, Punkt offen lassen, fehlende Quelle/Evidence und ausloesende Wiederaufnahmebedingung benennen. Mit zusaetzlicher Kapazitaet Quellenrecherche und JA-041-Fixturearbeit parallel moeglich; produktive Store-Schreibvorgaenge immer serialisieren.

  - [ ] JA-027.1 Dauerhaften Firmen- und URL-Bestand als vorhandene Grundlage absichern, nicht neu implementieren.

    Beschreibung: Die gelieferte Retention einmal gegen den aktuellen Akquisepfad pruefen. Keine weitere isolierte Retention-/TLS-Refactorserie. Nach jedem Import, Websitefund, Verifikationsresultat und Wiederanlauf bleiben alle bisherigen Firmen-/URL-Funde samt Herkunft erreichbar; ungepruefte Name-only-Funde bleiben Discovery-Kandidaten ohne produktive Promotion.

    Scope: `src/JobAgent.Persistence.psm1`, `src/JobAgent.CompanyInventory.psm1`, `tools/Import-JobAgentCompanyDiscovery.ps1`, vorhandene Store-/Hint-/Queue-Dateien sowie `docs/data-model.md`. Aenderungen nur bei nachgewiesenem Hindernis fuer JA-027.2/.3. Historische Fortschritte, Backups und Evidence aus dem vorherigen Plan erhalten. Keine automatische Loeschung alter Funde, keine Refresh-bedingte Entwertung einer belegten Firmenidentitaet und kein produktiver Testdatenimport.

    Ist-Stand (2026-09-13 10:15): Retention-Schema, idempotenter Import, NOT_OBSERVED_IN_SOURCE und Name-only-Aufbewahrung sind implementiert; aktuelle Mengen stehen in der Baseline. Die offene Checkbox ist ein Akzeptanzgate fuer den Gesamtschnitt, keine Behauptung fehlender Implementierung. Ungeklaerte historische Provenienz/Fixtureanteile: TODO durch vorhandene Herkunftsdaten abgrenzen, nicht als real annehmen.

    Abhaengigkeiten/Prioritaet: JA-040/CI-001 und vorhandene Retention; interner Score 100/100, weil Datenverlust alle Folgeergebnisse entwerten wuerde. Aufwand 0,5 PT / 0,5 Arbeitstag als Regression und Inventarabgleich, keine erneute Migration geplant. M2-A; read-only Quelleninventur parallelisierbar. Risiko: Schemaerweiterung oder Writerfehler; bei nicht reproduzierbar sicherem Store-Commit schreibende Livearbeit stoppen.

    Schritte:
    1. In den bestehenden Persistenz-/Inventartests einen isolierten Store mit Name-only-Fund, einer Firma aus drei Quellen, zwei gleichnamigen Firmen an verschiedenen Standorten, alter/neuer Karriere-URL und verschwundenem Snapshotrecord pruefen. Vorher-/Nachher-IDmengen, Herkunftslinks und Promotion-Zuordnung vergleichen: kein Verlust, keine falsche Zusammenfuehrung, Wiederholung ohne weitere Firmen/URLs. Abgelaufene oder fehlerhafte URLs bleiben gespeichert; Domain-/Karriere-/Scanstatus bleiben getrennt.
    2. Bestehenden Writer-/Resultatcheckpoint-Vertrag fuer Import → Website-Ermittlung → Verify abgleichen. Resultate vor Promotion sichern; Netzwerk ohne Store-Lock; atomare Publikation mit Backup und genau einem Writer. Abbruch vor Resultatsicherung, nach Resultatsicherung vor Storecommit und nach Storecommit vor Queuefortschritt isoliert pruefen: Wiederanlauf erzeugt weder Doppelpromotion noch URLverlust. Bereits abgedeckte Faelle wiederverwenden; nur fehlende Akquisepfade ergaenzen.
    3. Aus Store, Hints, Registry und Queue ein gemeinsames Startmanifest mit UTC-Stichtag, Git-HEAD, SHA256, Schema und Mengen erstellen. Queue-Abdeckung ueber candidate_id UND candidate_ids in beide Richtungen pruefen; Differenzen mit ID/Grund ausweisen. Reale Quelle, Fixture und UNKNOWN getrennt. Das Manifest an JA-027.2/.3 weiterreichen; keine Altstatistik als frische Messung kopieren.

    Evidence/Done: Bei Umsetzung `logs/jobagent/JA-027-retention-regression.json` und `logs/jobagent/JA-027-candidate-reconciliation.json` aktualisieren, Run-ID/Inputhashes und exakte Testcommands aufnehmen. 0 unbegruendete verlorene Firmen-/URL-IDs, 0 falsch zusammengefuehrte Identitaeten, jede Hint-/Queue-Differenz erklaert. Keine Netzverifikation fuer dieses Gate erforderlich.

    Funktionstest (bestehende Dateien, erst bei Umsetzung ausfuehren):
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyInventory.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1
    ~~~

    Audit: JSON-/ID-/Hashabgleich automatisiert; keine UI-Aenderung in diesem Unterpunkt, daher Viewport-/Device-Audit nicht anwendbar. Supertest: erst nach vollstaendigem JA-027, kein eigener Supertest-/Commit-Slice fuer diese Vorbedingung.

  - [x] JA-027.2 Quellen mit verwertbaren Website-/Karrierehinweisen priorisieren und die ausfuehrbare Queue automatisch nachfuellen.

    Beschreibung: Die 1.131 Website-Reviewfaelle nicht durch globale Statusresets scheinbar startbar machen. Bestehende zulässige Linkinformationen durchgaengig transportieren und nur mit neuer belastbarer Evidence reaktivieren. Ein Quellenbatch liefert dauerhaft gespeicherte neue Identitaeten/URLhinweise und einen anschliessend automatisch startbaren Discovery-/Verifyplan. 100 ist nur eine Batchobergrenze, keine Mindestmenge. Auch eine einzelne neue belegte Firma automatisch verarbeiten; keine Quelle zum Fuellen einer Testquote abfragen.

    Scope: `src/JobAgent.RegionalDiscovery.psm1`, `src/JobAgent.RegisterDiscovery.psm1`, `src/JobAgent.JobBoardDiscovery.psm1`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.SourceVerification.psm1`; `tools/Measure-JobAgentDiscoverySourceInventory.ps1`, `tools/Import-JobAgentCompanyDiscovery.ps1`, `tools/Import-JobAgentRegionalDirectories.ps1`, `tools/Import-JobAgentRegisterCandidates.ps1`, `tools/Import-JobAgentJobBoardEmployers.ps1`, `tools/Discover-JobAgentCompanyCandidateWebsites.ps1`; Source Registry, Snapshotmanifest und Discovery-Dokumentation. Keine neuen Quellanbieter/APIs als bereits verfuegbar behaupten. Websitehinweis ist weder Firmenbestaetigung noch Karrierefreigabe.

    Ist-Stand (2026-09-13 19:45): 35 registrierte Quellen und 29 Snapshot-Manifesteintraege sind ueber `tools/Measure-JobAgentDiscoverySourceInventory.ps1` erneut abgeglichen; `logs/jobagent/JA-027-source-inventory.json` weist weiterhin 1.833 Hints, 1.831 Queue-Cluster, 0 Hints-ohne-Queue und 0 Queue-ohne-Hint aus. Regional-, Register- und Jobboard-Adapter transportieren optionale `website_hint`-/`career_hint`-Felder mit strukturierter Source-Evidence, normalisieren relative URLs gegen die Quellseite und lehnen unsichere Schemes ab. `Update-JobAgentDiscoveryHintRetention` speichert diese URL-Hinweise dauerhaft als `WEBSITE_HINT`/`CAREER_HINT`; die Quelleninventur zaehlt strukturierte URL-Hints je Quelle. Neu umgesetzt: `tools/Invoke-JobAgentDiscoveryRefill.ps1` fuehrt bei fehlender startbarer Queue einen endlichen Snapshot-Nachfuellzyklus aus, importiert nur erlaubte neue oder geaenderte Quellen anhand persistierter Inputhashes, laesst gesperrte Quellen aus, baut die Kandidatenqueue neu und liefert `wake_at` fuer zukuenftige Retries. `tools/Invoke-JobAgentDailyRun.ps1` haengt diesen Refill vor Website-Ermittlung und Kandidatenverifikation in die automatische Akquisephase ein. Bestehende Community-/OSM-Quellen behalten ihren Sperrvertrag und persistieren weiterhin keine Website-/Karrierefelder. Indeed MANUAL_REVIEW_ONLY, LinkedIn REJECT, HWK ohne Snapshotfreigabe, BioM ohne Snapshotvertrag und IHK ohne Export-/API-Freigabe bleiben gesperrt/geparkt. JA-027.2 ist funktional geschlossen; JA-027.3 bleibt fuer Domain-only-/Karrierequellen-Vervollstaendigung offen.

    Abhaengigkeiten/Prioritaet: JA-027.1 fuer schreibenden Import; Recherche/Adapter-Fixtures unabhaengig von JA-041. Interner Score 99/100; Inputqualitaet und Wiederverwendung bestehender Links haben Vorrang vor weiteren Name-only-Mengen. Aufwand 2,5–4 PT / 2,5–4 Arbeitstage, Quellenfreigabe/Netzwartezeit zusaetzlich UNKNOWN. M2-A; Adapter-Fixtures und read-only Recherche parallel bei zusaetzlicher Kapazitaet. Risiken: unvollstaendige Pagination, falscher Firmenbezug, geaenderte Bedingungen und fehlende URLs.

    Schritte:
    1. Inventur je source_id mit Format, Eingangsdatei/Hash, Funddatum, Nutzungs-/Retentionbeleg, Pagination/Cursor, realen/Fixture-/UNKNOWN-Records, verwertbaren URLhinweisen und bereits bekannten Arbeitgebern erzeugen. Zuerst vorhandene erlaubte strukturierte URLrecords nutzen, danach erlaubte Profil-/Snapshotrefreshes, zuletzt neue Anbieter recherchieren. Innerhalb einer Klasse nach gemessenen neuen Karrierearbeitgebern pro Request absteigend, dann source_id aufsteigend; noch ungemessene Quellen bekommen deterministisch alphabetisch die ersten maximal 10 realen Records als begrenzte Erkundungsprobe. Gleiche Firmen zwischen Quellen deduplizieren; eine Quelle mit null Nettozuwachs nach 20 bearbeiteten realen Kandidaten fuer diesen Lauf parken und zur naechsten wechseln. Wenn weniger Records verfuegbar sind, alle vorhandenen pruefen und kleine Stichprobe kennzeichnen. Snapshot-only bleibt Snapshot-only; ohne freigegebenes Material keine automatische Liveabfrage.
    2. Optionale website_hint-/career_hint-Felder inkl. source_id, observed_url, record_id, observed_at und content_hash durch Register-/Jobboard-/Regionaladapter bis Hint-Store, Retention und Queue transportieren; URLs relativ zur belegten Quellseite aufloesen, unsichere Schemes ablehnen, Originalbeleg erhalten. Erlaubte OSM-website/contact:website-Felder nur nach dokumentierter Quellenentscheidung aufnehmen; keine Personen-/Telefon-/E-Mail-Daten. Offizielle Firmenidentitaet anschliessend anhand Name plus Standort oder Registermerkmal pruefen; ATS nur bei Firmen-/Mandantenbeleg. Ein neuer Evidenzhash, neu belegte Domain oder faelliger Retry reaktiviert genau betroffene Cluster; identischer Inhalt ohne neue Evidence loest keinen neuen Versuch aus. Unverifizierte Funde bleiben erhalten, widerspruechliche Identitaet bleibt Review.
    3. Quellenrefresh, Website-Ermittlung und Queue-Reconciliation in einen automatischen Nachfuellzyklus einhaengen. Bei freiem Akquisebudget und fehlender startbarer Arbeit die naechste faellige erlaubte Quelle abarbeiten; jede zweite Quellenwelle Freising vorziehen, falls freigegebene faellige Freisingrecords vorhanden sind. Neue Anbieter optional bei belegtem Bedarf konfigurieren, nicht als Chatpflicht: unterschiedliche Ansaetze aus Kammer/Branche, kommunalen Verzeichnissen, Freising Stadt/Landkreis, Forschungsausgruendungen, Technologieclustern und Organisations-Open-Data dokumentieren. Betreiber/URL/Datum/erlaubte Methode/Budget oder nachvollziehbaren erfolglosen Suchauftrag erfassen; keine erfundene Mindestzahl verfuegbarer Anbieter. Fortschritt/Cursor nach jeder Welle sichern, Limit als PARTIAL melden. Gibt es nur zukuenftige Retries, wake_at=min(next_attempt_at) ausgeben und Lauf beenden; nicht pollen und nicht „Quellen ausgeschoepft“ melden. Bei fehlender Quelle nur diese parken; andere zulaessige Quellen laufen weiter.

    Evidence/Done: Bei Umsetzung `logs/jobagent/JA-027-source-inventory.json`, `logs/jobagent/JA-027-source-research.json`, `logs/jobagent/JA-027-candidate-reconciliation.json` und je Lauf `logs/jobagent/JA-027-refill-<run-id>.json` (neu anzulegend) mit vor/nach-Zaehlern, Cursor, Entscheidungen, Inputhashes, Requestbudget und tatsaechlich geplanten Kandidaten-IDs. Aktionen READY_IMPORT, REFRESH_ALLOWED, TARGETED_REVIEW, PARKED und EXHAUSTED_WITH_EVIDENCE sind Reportentscheidungen, keine still neuen Registryklassen. Erschoepfung nur mit abgearbeiteter Pagination/Exportmenge im benannten Suchraum/Zeitfenster; Budgetende oder identischer Snapshot genuegt nicht. Keine reale Mindestmenge als Done-Gate; leere, einzelne und volle Fixturebatches verifizieren.

    Funktionstest: Adapter mit/ohne URL, relative URL, boese Schemes, verschiedene Schreibweisen, falsche gleiche Namen, UNKNOWN-Ort, Seite 2, Cursor-Resume, Quellenwechsel, gesperrte Quelle neben freier, Freising-Fairness, identischer/neuer Hash, zukuenftiger/faelliger Retry und 1.000 isolierte Fixtures; keine Fixturepromotion in den realen Bestand. Bestehende Tests gezielt ergaenzen:
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentRegionalDiscovery.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentRegisterDiscovery.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentJobBoardDiscovery.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
    ~~~

    Audit: Quellenfreigaben datiert gegen Betreiberbelege pruefen; je Quellenfamilie die alphabetisch ersten drei nichtleeren Record-IDs nachvollziehen (bei weniger alle). Jede neue Karrierequelle muss im Folgeschritt offiziellen Beleg erhalten. Keine UI-Aenderung vorausgesetzt; betroffene Coverage-Ansicht gemeinsam mit JA-027.3 pruefen. Supertest erst nach vollstaendigem JA-027 und gruenen Funktionstests; externe Recherche bleibt ausserhalb deterministischer CI.

  - [ ] JA-027.3 Karrierequellen vervollstaendigen, in den Jobstart integrieren und im WebIF anzeigen.

    Beschreibung: VERIFIED/ALREADY_VERIFIED_IN_STORE darf eine nur domainverifizierte Firma ohne Karrierebeleg nicht dauerhaft von der Karriereermittlung ausschliessen. Hostlimits steuern gleichzeitige Requests, nicht den Verlust weiterer Kandidaten eines Hosts aus dem logischen Batch. Vorhandene vier Worker, HTTP-Policy und Resultat-Resume nutzen; eine Orchestrierung erledigt Nachfuellen, Websitepruefung, Karriereverifikation und Coverage ohne manuellen Chatwechsel. Nutzbarer Fortschritt = neue eindeutige belegte Karrierearbeitgeber; technische Reparaturen, Domain-only und Wiederholungen getrennt ausweisen.

    Scope: `src/JobAgent.SourceVerification.psm1`, `src/JobAgent.CompanyInventory.psm1`, `src/JobAgent.Coverage.psm1`, `tools/Discover-JobAgentCompanyCandidateWebsites.ps1`, `tools/Verify-JobAgentCompanyCandidates.ps1`, `tools/Measure-JobAgentCompanyCoverage.ps1`, `tools/Invoke-JobAgentDailyRun.ps1`, `src/JobAgent.DailyRun.psm1`, `src/JobAgent.Report.psm1` und `src/JobAgent.Operations.psm1`. Geplant neu: `tools/Invoke-JobAgentAcquisitionRun.ps1` und `tests/Test-JobAgentAcquisitionRun.ps1`; diese existieren im Planungsstand noch nicht. Kein neuer ATS-Stellenlistenparser; lediglich offiziell verlinkte Karriere-/ATS-Ziele ermitteln. Fehlende Karrierequelle ist kein Nulltreffer fuer die Stellensuche.

    Ist-Stand (2026-09-13 19:57): Vier Worker, Hostsemaphoren fuer Redirect-/ATS-Hosts, atomare Einzelresultate, Checkpoint-Resume, Retry-After, FetchClient auto/curl/wsl-curl und Batchmetriken existieren. Neu: Domain-only-Bestandsfirmen mit fehlender Karrierequelle werden trotz vorherigem `VERIFIED`/`ALREADY_VERIFIED_IN_STORE` als `VERIFY_CAREER_SOURCE` wieder startbar; `Verify-JobAgentCompanyCandidates.ps1` kuerzt die Kandidatenauswahl nicht mehr nach Host, sondern protokolliert logische Hostwellen und trennt `official_career_verified_*` von `domain_only_*`. Funktionstests sind gruen. Blocker fuer kompletten JA-027-Abschluss: `tests/Test-JobAgentHtmlViewportAudit.ps1` bricht lokal bei Chrome-Headless 1920 px mit `GPU process isn't usable` ab; ohne diese visuelle Lane wird JA-027 noch nicht archiviert. Die gespeicherte VERIFIED-Gruppe umfasst 675 Queueeintraege, nicht 675 eindeutige Karrierearbeitgeber. Tatsächliche Zahl domainverifizierter Firmen ohne gueltige Karrierequelle und realer aktueller Karrierearbeitgeber: TODO aus dem Startmanifest eindeutig berechnen. Die alten 100er-/1.000er-Livegates entfallen nach Nutzerkorrektur; sie sind keine offene Abschlussvoraussetzung mehr.

    Abhaengigkeiten/Prioritaet: JA-027.1, Nachfuellvertrag aus JA-027.2; Scheduler-/Domain-only-Fixtures koennen waehrend Quellenklaerung bearbeitet werden. Interner Score 98/100, da Durchsatz ohne Eingang und richtige Zielzaehlung wertlos ist. Aufwand 3–5 PT / 3–5 Arbeitstage, externe Wartezeit UNKNOWN. M2-A; spaeter JA-041 parallel auf vorhandenen offiziellen Quellen, ein produktiver Writer. Risiken: geteilter ATS-Host, Weiterleitungsschleifen, falsche Konzernzuordnung, Rate-Limits, Abbruch und geringe regionale Ausbeute.

    Schritte:
    1. Domainbestaetigung und Karrierequellen-Ermittlung als getrennte Arbeitszustaende modellieren; bestehende Statuswerte nur additiv/kompatibel erweitern. Fuer Firmen mit belegter Domain ohne gueltigen Karrierebeleg einen wiederaufnehmbaren Karrierepruefauftrag erzeugen, auch wenn der zugehoerige Hint bereits VERIFIED ist. Alle beobachteten relevanten Links und offizielle Redirect-/iframe-/ATS-Verbindungen speichern; erfolgreiche offizielle Verifikation promotet Quelle, leerer Fund behaelt Domain und dokumentiert Suchumfang. Keine geratenen /karriere-Pfade als Beleg, keine fremden Konzernmandanten miterfassen. Initiale Pruefreihenfolge: gespeicherter Karrierehinweis, offizielle Homepage-Navigation, belegtes Portal/iframe-Ziel; normalisierte URL als Tie-Breaker. Nach unveraenderter erfolgloser Pruefung erst bei neuer Evidence oder faelligem Refresh erneut versuchen.
    2. Logischen Plan vor HTTP speichern: IDs, Herkunft, alter Status, Pruefgrund, Inputhashes, Faelligkeit, Initialhost und Ausschluesse. Die ersten maximal 100 realen priorisierten Kandidaten behalten und ueber Hostwellen abarbeiten, statt gleiche Hosts nach Auswahl zu verwerfen; vier globale Worker, maximal ein gleichzeitiger Request je tatsaechlichem Host einschliesslich Redirect/ATS, strengere Quellenregel gewinnt. Hostbudget ohne freie Slots verschiebt Auftrag innerhalb des Plans. Orchestrator als einmaligen, endlichen Lauf implementieren: Startvalidierung/Resume → Nachfuellen → Website-/Karrierepruefung → serieller Commit/Checkpoint → Firmenreport atomar publizieren → regulaeren Stellenlauf fortsetzen. Vorherigen Report bis erfolgreicher Publikation erhalten. Getrennte Akquise-/Scanbudgets; erschöpfte Quellen oder Retries blockieren den normalen Stellenlauf nicht, Persistenzfehler stoppen schreibende Folgearbeit fail-closed. Geplante CLI: -ProjectRoot, -MaxCandidatesPerBatch (100), -MaxRunMinutes (60), -MaxRequests (2000), -WorkerCount (4), -HostConcurrency (1), -FetchClient (auto), -Resume und -FixtureMapPath; Parameter erst bei Implementierung verfuegbar. Jedes Limit vor dem naechsten Request/Batch pruefen; In-flight-Requests unter Timeout kontrolliert beenden und checkpointen. Sourcespezifische Budgets gewinnen. Kein globales Retryreset und kein dauerhaft blockierender Vordergrundprozess. Ende: Laufbudget erreicht, nur zukuenftige Retries oder keine erlaubte ausfuehrbare Arbeit; jeden Grund und Resumecommand protokollieren.
    3. Im regulaeren Jobstart die Firmenansicht auf Port 8500 aktualisieren: Name, belegter Ort/Gebietsstatus, offizielle Website, Karriere-/Jobs-/Stellenangebote-/ATS-Link, Quellenstatus und Pruefdatum. Firmen ohne aktuelle Stellen bleiben sichtbar; fehlende Karrierequelle offen kennzeichnen. Hinweise/Domain-only und vollstaendig belegte Firmen getrennt anzeigen. Nach erfolgreicher Publikation ist der Stand beim Laden/Neuladen des WebIF sichtbar, ohne manuellen Reportcommand oder Browserneustart. Bereits die Basisansicht hat Firmenname-/Gebietsfilter und Zugang zu allen Datensaetzen. Je Start neue eindeutige Arbeitgeber, Quellenzuwachs, Requests, Dauer, Fehler, Stopgrund und Cursor ausgeben. Filteraenderungen loesen keine Akquise/HTTP aus. 100er-/1.000er-Mengen nur als isolierte Skalierungsfixtures, kein realer Mengenlauf fuer Roadmap-DoD.

    Evidence/Done: Bei Umsetzung `logs/jobagent/JA-027-acquisition-<run-id>.json` (neu), Batch-/Resume-Manifeste und aktualisierte Firmen-HTML-Ausgabe aus dem regulaeren Start. Runcommand, Gitstand, Inputhashes, Quellenentscheidungen, Budgets, vor/nach-Zaehler, Stopgrund und Reportpfad erfassen. Abnahmefixture mit bekanntem Arbeitgeber, neuer Firma samt Website/Karrierelink, Name-only-Fund und leerer Karrierequelle: neue belegte Firma nach regulaerem Start genau einmal mit beiden Links im WebIF; zweiter Start null Dubletten; leerer/budgetierter Eingang korrekt. Offiziellen Firmen-/Quellenbezug verifizieren, Domain-only/Fixture nicht als reale Vollverifikation zaehlen. Keine reale Mindestmenge oder manuelle Firmenabfrage fuer diesen Roadmap-Abschluss.

    Funktionstest: 100 Kandidaten auf einem Host werden seriell innerhalb des logischen Plans verarbeitet; verschiedene Hosts nutzen freie Worker, Redirects respektieren Ziellimit; Domain-only wird weiterverarbeitet, bestehende gueltige Karrierequelle nicht doppelt gezaehlt. Zusaetzlich 429/Retry-After, Null-Eligibility, Zeit-/Requestbudget, nur zukuenftige Retries, Quellenwechsel, Writerfehler, Abbruch an Commitgrenzen, neuer Evidenzhash, falscher Konzernmandant, leeres Karriereportal, Netto nach Ablauf und vorhandene P50/P95 mit n=0/1/100, ohne neue Metrikengine als Nebenbaustelle. Neue Orchestrierung mit Fake Clock/Fetcher und isoliertem Store testen; 1.000 Fixtures sind kein Live-Mengennachweis.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentCompanyDedupeScale.ps1
    # Geplante neue Testdatei; erst nach Implementierung ausfuehren:
    pwsh -NoProfile -File .\tests\Test-JobAgentAcquisitionRun.ps1
    # Pflicht fuer Startintegration und Firmenanzeige:
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1
    ~~~

    Audit: Automatischer Store-/Manifest-/Checkpoint-Abgleich plus echte Quellenbelege; Coverage bei 800/1366/1920 px (390 px bei betroffener Mobilansicht) ohne Clipping/Overlap, mit getrennten Firmen-/Domain-/Karriere-/Scanmengen, lesbaren Statuswerten und unverifizierten URLs ohne offizielle Freigabe. Vorhandene UI-001-Screens bleiben bindend; geplante neue Evidence unter `doc/roadmap-screenshots/JA-027-acquisition-<width>.png`. Devserver ausschliesslich ueber ci.cmd devserver-start auf 8500. Android-/Device-Lane nicht anwendbar. Vollstaendige Stellen-/Filter-UI bleibt UI-001.

    Supertest/Abschluss: Erst bei allen erfuellten fachlichen JA-027-Gates und gruenen Funktionstests .\ci.cmd supertest; bei Fehler nur betroffene Funktionstests zur Diagnose, danach Abschlussgate erneut. In diesem reinen Planungsauftrag kein Supertest, kein Liveakquiselauf, kein fachliches Abhaken. Nach echter Umsetzung Roadmap/Todo/Handoff im selben Abschluss synchronisieren und STP ausfuehren; nach belegter Startintegration/Firmenanzeige archivieren. JA-042 sichert den Betrieb ab; reales Firmenwachstum erfolgt in spaeteren Benutzerlaeufen.

- [ ] JA-041 Berufsneutrale Stellenerfassung von Suchprofilen trennen #comment: Regionale Daten automatisch sammeln und berufsneutral filtern statt manuell Firmenwellen abarbeiten.

  Beschreibung: Berufsneutrale Stellenerfassung von Suchprofilen trennen. Abnahme ueber drei funktionale Unterpunkte, keine reale Firmenquote.
  Ist-Stand (2026-09-13): tools/Invoke-JobAgentDailyRun.ps1 setzt SearchTerms auf Head of IT, Director IT, IT Leitung, IT-Leitung, Leiter IT und CIO. Programmvertrag/Klassifikation sind auf IT-Fuehrung zugeschnitten. Gelieferte Parser-/Paginationarbeit bleibt erhalten; MSG bleibt offener Einzelfall, keine Voraussetzung fuer alle anderen Berufe.
  Abhaengigkeiten: JA-040 und vorhandene offizielle Quellen; neue Firmen aus JA-027. Keine Mengenabhaengigkeit.
  Aufwand/Dauer: 3–5 PT / 3–5 Arbeitstage; ein Entwickler/Agent, acht Nettoarbeitsstunden pro PT; externe Wartezeit UNKNOWN. Kein verbindlicher Termin oder weitere Kapazitaet zugesagt.
  Prioritaetsscore: 98/100, Planungsentscheidung. Ordnungsbegruendung: neutrale Attribute vor allgemeinen Filtern.
  Risiken: implizite Altfilter, fehlende Attribute, partielle Quellen und veraltete Anzeige. UNKNOWN sichtbar erhalten. Meilenstein/Parallelisierung: M2-B; ein zusammenhaengender Slice, Fixtures bei zusaetzlicher Kapazitaet parallel, produktive Writer seriell.

  - [ ] JA-041.1 Erfassung ohne impliziten Berufsfilter als Standard liefern.

    Beschreibung: Auch Buchhaltung, Pflege, Handwerk, Vertrieb und Ausbildung werden bei belegter regionaler Stelle gesammelt; IT-Fuehrung ist nur ein optionales Suchprofil.
    Scope: tools/Invoke-JobAgentDailyRun.ps1; src/JobAgent.LiveScan.psm1; src/JobAgent.DailyRun.psm1; manual/PROGRAM.md. Kein Frameworkwechsel, keine Gebietsaufweitung oder Bewerbungen.
    Ist-Stand (2026-09-13): Grundlagen/Altgrenzen siehe Hauptpunkt; diese neue Anforderung ist noch nicht fertig verifiziert.
    Abhaengigkeiten/Prioritaet: Hauptpunkt-Grundlagen; Score 100/100 intern, Reihenfolge Vertrag → Integration → Abnahme. Aufwand/Dauer anteilig 40 % der Hauptpunktschaetzung bei gleicher Kapazitaet. Meilenstein M2-B. Risiko: Altvertrag oder unvollstaendige Daten verfälschen Ergebnis; Fixtures vor produktiver Integration.
    Schritte:
    1. Daily-SearchTerms und Live-Policy auf berufsneutralen Standard umstellen: leere Begriffe bedeuten alle Berufe, nicht die alte IT-Fallbackliste. Explizite CLI-/Profilbegriffe kompatibel als eingeschraenkten Suchscope dokumentieren. Alle impliziten IT-Vorselektionen zwischen Start, Request und Normalisierung verfolgen und entfernen.
    2. Offizielle allgemeine Joblisten/Feeds ohne Berufsfilter verwenden. Quelle mit zwingendem Suchterm und ohne allgemeine Liste als eingeschraenkt/PARTIAL dokumentieren, nicht als vollstaendig leer. Pagination, Timeout und Resultatlimits weiterhin sichtbar begrenzen. Kein Filter im WebIF veraendert diesen Erfassungsauftrag.
    3. manual/PROGRAM.md und Datenvertrag nach ausdruecklicher Nutzerkorrektur synchronisieren: Berufsprofil steuert Anzeige, nicht Firmenakquise. Muenchen mit bestehendem 20-km-Bereich und Freising beibehalten; Firmenstandort und Stellenort getrennt. Kein pauschaler Bayern-/Deutschland-Match; UNKNOWN explizit.
    Evidence/Done: Bei Umsetzung neu `logs/jobagent/JA-041-1-acceptance.json`: Gitstand, Input-/Resultat-IDs, Commands/Exitcodes und erwartete/erhaltene Zaehler. Alle drei Schritte positiv/negativ nachgewiesen; keine offene Kernanforderung. Geplante Screens bei sichtbaren Aenderungen `doc/roadmap-screenshots/JA-041-1-<width>.png`; noch nicht vorhandene Artefakte.
    Funktionstest: Bestehende Tests um die genannten Faelle ergaenzen; isolierter Store, Fake Clock/Fetcher und exakte Assertions.
    ~~~powershell
    pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
    pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1
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

