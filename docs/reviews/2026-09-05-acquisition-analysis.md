# Akquise- und Scan-Analyse zum Webreview 2026-09-05

Prüfzeitpunkt: 2026-09-05T17:04:19Z. Grundlage: lokaler Istbestand, Quellcode und gespeicherte Live-Nachweise. Dieser Teilreview hat keine externen Massenscans oder produktiven Importe ausgeführt. Die folgenden Werte sind lokale Bestandsmessungen, keine behauptete aktuelle Marktdeckung.

## Ergebnis und Zieldefinition

Das Ziel von mindestens 1.000 untersuchten Firmenkarriereseiten ist nicht erreicht. Der Bestand enthält 479 eindeutige Firmendomains, davon 433 mit Karriereverifikation und 432 unterschiedliche Karriere-URLs. Ein vorhandener Karriere-Link belegt noch keinen Stellenangebotsscan. Die gespeicherten Live-Piloten dokumentieren Versuche für insgesamt fünf eindeutige Firmen, drei technische SUCCESS-Ergebnisse und keine verifizierten passenden Stellen. Ein vollständiges Auslesen der jeweiligen Stellenbestände ist dadurch nicht belegt.

Für das neue Ziel sind mindestens diese voneinander getrennten Kennzahlen erforderlich: eindeutige Arbeitgeberidentitäten, eindeutige offizielle Karrierequellen, tatsächlich live versuchte Arbeitgeber, vollständig untersuchte Stellenlisten, unvollständige/gesperrte Prüfungen und passende aktuelle Stellen. Gemeinsam genutzte Konzernportale benötigen zusätzlich eine Portal-/Mandantenidentität. 1.000 Kandidaten, Queue-Einträge oder wiederholte Abrufe desselben Portals dürfen die Zielzahl nicht erfüllen.

## Belegter Istbestand

| Messgröße | Ergebnis | Primärbeleg |
|---|---:|---|
| Firmen / eindeutige kanonische Domains | 479 / 479 | `data/jobagent/store.json`, `companies` |
| Firmen mit `CAREER_URL_VERIFIED` | 433 | `companies.verification_status` |
| Firmen mit ausschließlich `COMPANY_DOMAIN_VERIFIED` | 46 | `companies.verification_status` |
| Unterschiedliche nichtleere Karriere-URLs | 432 | `companies.career_url` |
| Offizielle Jobquellen / zugehörige eindeutige Firmen | 439 / 433 | `job_sources` |
| Quellentypen | ausschließlich 439 `CAREER_PAGE` | `job_sources.source_type` |
| Firmenstatus PENDING / SUCCESS / FAILED | 476 / 2 / 1 | `companies.scan_status` |
| Firmen mit letztem erfolgreichem Scan | 2 | `companies.last_successful_scan_at` |
| Persistierte Läufe / Versuche / betroffene Firmen | 6 / 10 / 3 | `scan_runs`, `scan_attempts` |
| Persistierte Jobs / passende Jobs | 3 / 0 | alle drei `classification.result=REJECTED` |
| Discovery-Kandidaten / Identitätscluster | 1.790 / 1.785 | `company-candidate-verification.queue.json` |
| Queue-Aktion: Website ermitteln | 1.120 | `action_counts.DISCOVER_OFFICIAL_WEBSITE` |
| Queue-Aktion: bereits im Store verifiziert | 662 | Kandidatencluster; keine 662 zusätzlichen Firmen |
| Queue-Aktion: offizielle Website prüfen / manuell entscheiden | 2 / 1 | `action_counts` |
| Queue-Status bereit | 0 | `ready_total` |
| Gespeicherte Live-Pilotdateien | 2 | 2026-08-17 und 2026-08-24 |
| Eindeutige Firmen mit Live-Pilotversuch | 5 | Vereinigung beider `companies`-Listen |
| Eindeutige Firmen mit technischem Live-SUCCESS | 3 | Vereinigung beider `attempts`-Listen |
| Verifizierte passende Stellen in Live-Piloten | 0 | beide `verified_matching_jobs=[]` |
| Manuelle offizielle Importwellendateien / Importzeilen | 53 / 408 | `company-discovery.official.wave-*.json` |

Der Karriere-Link `https://stadt.muenchen.de/rathaus/karriere.html` ist zwei Firmen zugeordnet: Landeshauptstadt München und Portal München Betriebs-GmbH & Co. KG. Ob die Arbeitgeberidentitäten fachlich zusammenzuführen sind, ist ungesichert; für eindeutige Webseiten zählt dieser identische Link einmal.

Der Store kennt nur die Firmen BMW, Siemens und SWM in `scan_attempts`. Der Live-Pilot vom 24. August nennt zusätzlich Allianz und Munich Re, dessen Lauf fehlt jedoch in `store.scan_runs`. Die Ursache ist ungesichert. Der neuere Lognachweis darf nicht still mit dem aktuellen Store gleichgesetzt werden.

Standortzählung über einzelne `locations`-Einträge: 425 MUNICH, 31 MUNICH_20KM, 21 FREISING, 2 REMOTE_WITH_TARGET_REFERENCE, 1 UNKNOWN. Diese Summe zählt Standorte, keine eindeutigen Firmen und keine aktuellen Stellen.

## Priorisierte technische Befunde

### A1 – Akquise hängt an Website-Ermittlung, nicht an fehlenden Firmennamen

Von 1.120 `DISCOVER_OFFICIAL_WEBSITE`-Einträgen stammen 1.044 aus OpenStreetMap. 1.087 Einträge tragen den letzten Grund „Quellentyp ist nicht als offizieller Website-Ermittlungsbeleg zugelassen.“ Weitere 28 haben keine eindeutig passende Domain auf ihrer offiziellen Quellseite, drei keine zulässige Quell-URL und zwei keinen offiziellen Domainhinweis.

`src/JobAgent.SourceVerification.psm1:522` erlaubt für die automatische Domainermittlung nur entsprechend offizielle Evidenzklassen. `:666` bricht für die große Restmenge ab, bevor eine unabhängige Firmenwebsiteprüfung stattfinden kann. `tools/Discover-JobAgentCompanyCandidateWebsites.ps1:243` lässt bereits versuchte Einträge nur in einem eng definierten Sonderfall erneut zu; allgemein datumsabhängiger Retry für Netzwerkfehler ist hier nicht umgesetzt.

`src/JobAgent.RegionalDiscovery.psm1:267` übernimmt Namen, Standort und Provenienz, jedoch keine unverifizierten Websitehinweise. Die bestehenden GitHub-/OSM-Quellen haben `evidence_level=DISCOVERY_HINT`; diese Hinweise sind zu Recht kein offizieller Beleg. Für schnelle Akquise fehlt aber die getrennte Stufe „potenzielle Domain aus Hinweis → unabhängige Prüfung der offiziellen Domain → Karrierepfad“. Offizieller Beleg und zulässiger Recherchehinweis sollten getrennte Datenfelder und Übergänge erhalten; die bestehende Verifikationsschranke darf nicht einfach abgeschaltet werden.

Empfehlung: vorhandene Domainhinweise mit Provenienz unverifiziert erhalten, Firmen-/Standortidentität auf der Zielwebsite belegen, mehrdeutige Namen in Review lassen, positive Domains direkt an Karriereverifikation und atomaren Import weiterreichen. Für reine Namen ohne Domain ist eine zusätzliche belegte Such-/Verzeichnisquelle erforderlich. Eine externe Such-API und deren Kosten sind bislang nicht gesichert.

### A2 – Der generische Live-Adapter garantiert keinen vollständigen Stellenscan

`src/JobAgent.LiveScan.psm1:25` setzt standardmäßig 25 Firmen, zehn Kandidaten und fünf Detailabrufe. Der Parser nimmt in `:438` die ersten passenden Links in HTML-Reihenfolge; `:635` lädt nur die ersten fünf. Die sehr breite Linkheuristik in `:212` akzeptiert bereits „job“, „career“ oder „it“. Relevante spätere Rollen werden dadurch verdrängt.

Read-only Funktionsprobe: zehn synthetische allgemeine Joblinks gefolgt von „IT Manager München“, `MaxResults=10` und `SearchTerms=@('IT Manager')`. Ergebnis: zehn allgemeine Links, kein IT-Manager-Kandidat. Suchbegriffe wirken hier nicht als Relevanzsortierung vor dem Limit.

Im vorhandenen Live-Code sind ATS-Marken lediglich Teil einer URL-Heuristik (`:201`). Die untersuchten Live-/Daily-/SourceAdapter-Module enthalten keine ATS-spezifischen Paginierungs-, Cursor- oder Listen-API-Läufe. `New-JobAgentLiveRawJob` (`:549`) übernimmt den Titel aus dem Link, extrahiert nur 500 Zeichen Seitentext und übernimmt den Standort aus dem Listenkandidaten oder UNKNOWN. Eine nachgelagerte strukturierte Detailseitenauswertung ist hier nicht vorhanden. Bereits dadurch können Führungsverantwortung und Standort außerhalb dieses Ausschnitts verloren gehen.

Reale Folge im Bestand: „Job Search“, „FAQs & Support …“ und „IT-Expert*in“ auf einer SWM-Themenseite wurden als Jobs persistiert, anschließend korrekt verworfen. Beim Allianz-Piloten ist `career-development` mit Titel „READ MORE“ als `official_detail_pages_checked` erfasst. Technischer HTTP-Erfolg ist kein Nachweis einer Stellenanzeige oder vollständigen Suche.

Empfehlung: Stellenlisten und Navigation unterscheiden, strukturierte Details auswerten, Relevanz vor Detailbudgets bewerten, Portaladapter anhand eines repräsentativen lokalen Firmeninventars priorisieren. Pagination, Filter und dokumentierte Abbruchgründe müssen zum Scanergebnis gehören. Unvollständige Scans dürfen weder als vollständige Coverage noch als „keine Jobs“ gewertet werden.

### A3 – IT Manager und IT Lead passen nicht zum bisherigen Executive-Schwerpunkt

`src/JobAgent.Classification.psm1:106` gibt IT-Leiter/Head-of-IT einen starken Titelbonus; IT Manager und IT Lead fehlen. `:229` verwirft Teamlead-Rollen ohne zusätzliche Führungs-/Strategiebelege. Das war ein engeres Suchprofil als der aktuelle Nutzerauftrag.

Read-only Funktionsprobe mit Standort München, Vollzeit, Hybrid und Beschreibung „Verantwortung für den Betrieb der IT.“:

| Titel | Klassifikation | Score |
|---|---|---:|
| IT Manager | REJECTED | 24 |
| IT Lead | REJECTED | 24 |
| IT Team Lead | REJECTED | 0 |
| IT-Leiter | POSSIBLE | 62 |

Mit Beschreibung „Personalverantwortung fuer ein Team.“ steigen Manager/Lead/Team Lead auf POSSIBLE/48 und IT-Leiter/Head of IT auf MATCH/86. Die Differenz ist reproduziert, beweist jedoch nicht, dass jede Manager-Rolle passend wäre. Titel ohne Aufgabenbeleg sollten überprüfbar bleiben; Konfiguration nach Rollenfamilie, Führungsverantwortung und Standort ist nötig. IT-Projektmanager oder fachfremde Manager sollen dadurch nicht pauschal Match werden.

### A4 – Serielle Netzwerkarbeit blockiert den gesamten JSON-Store

`src/JobAgent.DailyRun.psm1:514` nimmt den Store-Lock vor sämtlichen Abrufen. `:521` führt Firmen und Quellen seriell aus; erst `:559` schreibt das Gesamtergebnis. Kandidatenverifikation arbeitet identisch in `tools/Verify-JobAgentCompanyCandidates.ps1:586`, `:610`, `:627`. Website-Discovery ist ebenfalls seriell (`tools/Discover-JobAgentCompanyCandidateWebsites.ps1:291`) und schreibt Hint-Store und Queue unmittelbar mit `Set-Content` (`:303`, `:307`).

Dadurch können lange Timeouts parallele Akquise/Scans blockieren. Bei Prozessabbruch vor dem finalen Store-Write fehlt ein dauerhafter Fortschrittscheckpoint. `Invoke-JobAgentLiveFetchWithRetry` (`src/JobAgent.LiveScan.psm1:93`) wiederholt fehlgeschlagene Abrufe ohne Zeitabstand oder statusabhängige Retry-After-Auswertung. Das reine Erhöhen von MaxCompanies verbessert weder Durchsatz noch Wiederanlauf.

Empfehlung: begrenzte globale und hostbezogene Parallelität, gecachte Verzeichnisabrufe, Timeout-/Retry-Budgets, persistierte Ergebnisse pro Arbeitseinheit und kurzer einzelner Commit unter Lock. Vor der Parallelisierung gemeinsame Hint-/Queue-Schreibpfade atomar und konfliktfest machen. Durchsatz erst nach gemessenem repräsentativem Lauf versprechen.

### A5 – Zielmetriken, Roadmap und historische Nachweise sind nicht synchron

`Roadmap.md:8` nennt noch 39 Arbeitgeber. Der Kopf priorisiert UI vor weiteren Datenwellen, Handoff/Todo fokussieren JA-027. `docs/ROADMAP.md` ist zusätzlich eine Bootstrap-Roadmap mit anderen Projektzielen. `Roadmap_index.md` nennt Stand 27. August und nur JA-027, obwohl UI-001 aktiv ist. `Roadmap_archive.md` führt mehrfach wiederverwendete JA-025/JA-026 unter unterschiedlichen Themen. Diese Historie muss erhalten bleiben, aber ein eindeutiger aktueller Index und neue kollisionsfreie IDs sind erforderlich.

Der manuelle Importbetrieb umfasst 53 Wellendateien mit nur zwei bis 16 Zeilen je Datei. Weitere fünf Firmen je Slice erfüllen den Wunsch nach schneller Akquise nicht. Messbare zusammenhängende Kampagnen ersetzen die alphabetische Fortschreibung der Wellen, ohne Import-/Verifikationsbelege zu verlieren.

## Empfohlene zusammenhängende Folgeslices

Annahme: ein Entwickler/Agent mit voller technischer Arbeitskapazität; ein Personentag (PT) entspricht ungefähr acht Nettoarbeitsstunden. Externe Websiteänderungen, Betreiberlimits und manuelle Entscheidungen können die Kalenderdauer verlängern. Scores sind qualitative Prioritäten von 0 bis 100, keine gemessenen Kennzahlen. Die globale Roadmap sollte UI-Ergebnisse des separaten Webreviews integrieren.

1. **Messvertrag und beschleunigte Akquise bis zum vollständigen Scanauftrag.** Abhängigkeiten: vorhandene Source Registry, Queue und atomarer Store; aktuelle Baseline dieses Reviews. Aufwand: 3–5 PT; Dauer: 4–7 Arbeitstage. Prioritätsscore: 100. Ordnungsgrund: 1.120 Kandidaten sind bereits vorhanden, fehlen aber im nutzbaren Domain-/Karriereprozess. Scope: untrusted Domainhinweise, unabhängige offizielle Verifikation, fällige Retry-Zustände, kurze atomare Writes, begrenzte Worker, durchgehender Run-/Coverage-Nachweis und automatische Weitergabe scanbarer Quellen. Risiko: Namensverwechslungen, Konzern-/Mandantenidentität, fremde Nutzungsgrenzen und API-Verfügbarkeit. Meilenstein M1: repräsentative 100 Kandidaten verarbeitet, neue eindeutige Domains/Quellen und manuelle Reste mit realem Durchsatz ausgewiesen; Wiederanlauf ohne Doppelimport und Storeverlust. Parallelisierung: reine Extraktions-/UI-Arbeit möglich; gemeinsame Queue-/Store-Veröffentlichung seriell. Funktionsverifikation: CompanyCandidateVerification, RegionalDiscovery, SourceVerification, Persistence, Coverage plus gezielte Abbruch-/Retry-Fixtures; keine Netzwerkmassentests in CI.

2. **Vollständiger Stellenabruf für IT-Leitung, IT Lead und IT Manager einschließlich Suchfiltern.** Abhängigkeiten: stabiler Nachweisvertrag aus Slice 1; Entwicklung anhand der bereits 433 vorhandenen Karrierequellen sofort möglich. Aufwand: 3–6 PT; Dauer: 4–8 Arbeitstage. Prioritätsscore: 98. Ordnungsgrund: ein größerer Domainbestand allein liefert noch keine Stellen; aktuelle Limits und Executive-Klassifikation verlieren passende Rollen. Scope: Navigationserkennung, Detail-JSON-LD, relevante ATS-/Listenadapter mit Pagination, belegte Standorte, konfigurierbare Rollenfamilien, klare Vollständigkeits-/Blockadezustände und Filterparameter. Risiko: unterschiedliche ATS, JavaScript-Seiten, Standortmehrdeutigkeit und unvollständige Detailtexte. Meilenstein M2: repräsentative mindestens 25 unterschiedliche Firmenquellen mit belegter Auslesetiefe, reproduzierbaren Treffer-/Negativfällen und aktuellen Detailseiten; keine erfundene Erfolgsquote. Parallelisierung: Anbieteradapter und UI-Filter unabhängig entwickelbar; kanonischer Datenvertrag gemeinsam. Funktionsverifikation: LiveScan, SourceAdapters, Classification, DailyRun, StatusMachine und Report; gezielte Cases für Pagination, 11. relevanten Link, Manager/Lead und unklare Standorte.

3. **Kampagne für mindestens 1.000 eindeutige untersuchte Firmenkarriereseiten samt Abschlussnachweis.** Abhängigkeiten: M1 und M2; ausreichende belegte Kandidatenbasis. Aufwand: 1–2 PT Betriebs-/Abnahmearbeit zuzüglich nicht gesichert schätzbarer manueller Websiteentscheidungen; Dauer: vor Durchsatzmessung offen, Planungsannahme 2–5 Arbeitstage nach M2 ohne größere neue Blockaden. Prioritätsscore: 95. Ordnungsgrund: belastbare Zielerfüllung folgt erst nach funktionierender Akquise und Stellenauswertung. Scope: automatisierte Nachfüllung, faire Hostlimits, Fortsetzung nach Abbruch, Ergebnisfilter und exportierbarer Nachweis je Arbeitgeber/Portal. Risiko: die aktuellen 1.785 Cluster können durch weitere Deduplikation und Standortprüfung unter die benötigte Zahl schrumpfen; nicht jede Firma hat eine Karrierequelle. Meilenstein M3: mindestens 1.000 eindeutige Karrierequellen tatsächlich untersucht, pro Quelle Zeitpunkt, Abruf-/Ausleseumfang, Suchprofil und Ergebnis; gesperrte oder unvollständige Fälle separat, passende Stellen nur mit offizieller Detailquelle. Parallelisierung: erlaubte unterschiedliche Hosts begrenzt parallel, Persistenz und Abschluss seriell. Funktionsverifikation: Kampagnen-/Coverage-Nachweise und relevante Fehlerfixtures; Supertest erst nach vollständigem Roadmap-Punktabschluss, anschließend Roadmap-/Todo-/Handoff-Sync und STP.

## Reproduzierbarkeit und Grenzen

Die Bestandszahlen stammen aus read-only PowerShell-JSON-Auswertungen. Funktionsproben importierten ausschließlich bestehende Module und erzeugten In-Memory-Daten. Kein produktiver Store, keine Queue und kein Hint-Store wurden durch diesen Review verändert. Eine erste zusätzliche Klassifikationsprobe hatte einen Shell-Pipeline-Syntaxfehler; sie wurde korrigiert und erfolgreich erneut ausgeführt. Die oben angegebenen Resultate stammen aus den erfolgreichen Ausführungen.

SHA-256 der geprüften Datenstände:

- `data/jobagent/store.json`: `758483720A80676745A79BA61FE23E3FABD47C6AB500F50E6818CD107364923A`
- `data/jobagent/company-candidate-verification.queue.json`: `3513E27E9807E0A138F5DBAEAC6C6653C9CB1187FEA06AC7EEE1F30525AC1CA0`
- `data/jobagent/company-discovery.hints.json`: `CFB2268432200D5BF5C288C090376A66C83C21C5E0F7003C27B980CABDB078B7`

Weitere technische Beobachtung ohne eigenständige Laufzeitverifikation: beide HTTP-Wrapper lesen den finalen Redirect aus `BaseResponse.ResponseUri` (`SourceVerification.psm1:242`, `LiveScan.psm1:67`). Für den eingesetzten PowerShell-7-HTTP-Typ sollte die tatsächliche Redirect-API gezielt gegen einen lokalen Redirect-Fixture geprüft werden; bis dahin ist die korrekte Weiterleitungsprovenienz nicht gesichert. Diese Beobachtung ist kein bestätigter Laufzeitfehler.
