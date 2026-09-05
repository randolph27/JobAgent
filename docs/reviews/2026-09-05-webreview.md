# Webreview JobAgent – 5. September 2026

Der JobAgent hat eine brauchbare Grundlage für Firmeninventar, Quellenbelege und lokale Berichte. Das Nutzerziel – mindestens 1.000 Firmenkarriereseiten auf IT-Leiter-, IT-Lead- und IT-Manager-Stellen für München/Freising untersuchen – ist **nicht erreicht**. Die wichtigsten Hindernisse sind eine blockierte Website-Ermittlung, unvollständige Stellenextraktion und Fehler bei Jobidentität, Aktualisierung und Matching. Die UI ist als Verzeichnis teilweise lesbar, als Stellensuche noch nicht logisch bedienbar.

Dieser Arbeitsschritt liefert den umfassenden Produkt-/Code-/Browserreview und die bereinigte Ausführungsroadmap. Er implementiert die gefundenen Produktkorrekturen noch nicht und behauptet keinen 1.000er-Webscan. Der produktive Store bleibt unverändert.

## Umfang und Belege

Geprüft wurden der vollständige lokale Firmen-/Jobbestand, Kandidatenqueue, gespeicherte Live-Pilotbelege, Discovery-/Verifikations-/Scan-/Klassifikations-/Status-/Reportcode und die zugehörigen Funktionsverträge. Im echten Browser wurden die produktive Coverage-Seite, der Daily-Report als ausdrücklich synthetische Viewport-Fixture und der Einstieg auf Port 8500 untersucht. Vier Viewports: 1920, 1366, 800 und 390 px; Aufklappen der Diagnose und Tastaturfokus wurden zusätzlich geprüft. Externe Recherche: gezielte Stichprobe von acht Arbeitgeberportalen einschließlich zwei konkreter Rollen-Detailseiten und regionaler Discovery-Referenzen. Das ist keine repräsentative Erfolgsquote und keine Prüfung aller verlinkten Stellen.

Ausgangscommit: `ce6e8ba48016e91933c4ad58311bd9e898fb3ba0`. Messwerte und Hashes: [Baseline](2026-09-05-baseline.json). Technische Details mit Datei-/Zeilenangaben und Reproduktionscode: [Akquise](2026-09-05-acquisition-analysis.md), [Stellenmatching](2026-09-05-matching-analysis.md), [UI-Codeanalyse](2026-09-05-ui-code-analysis.md). Die priorisierte, verbindliche Reihenfolge steht ausschließlich in [Roadmap.md](../../Roadmap.md); Teildokumente enthalten eigenständige Vorbewertungen.

## Was tatsächlich vorhanden ist

| Messgröße | Befund | Bedeutung |
|---|---:|---|
| Firmen im Store | 479 | Gespeicherte Firmen; keine 479 abgeschlossenen Stellensuchen |
| Firmen mit Karriereverifikationsstatus | 433 | Teilweise widersprüchlich zur effektiven Linkfreigabe |
| Unterschiedliche nichtleere Karriere-URLs | 432 | Gemeinsame Portale/Aliasse brauchen eigene Deduplizierung |
| Gespeicherte JobSources | 439 | Im Store alle CAREER_PAGE; die kombinierte Registry zählt anders |
| Firmen PENDING | 476 | Ohne abgeschlossenen Scanstatus |
| Firmen mit erfolgreichem Scanzeitstempel | 2 | Historischer technischer Erfolg, kein Vollständigkeitsbeleg |
| Gespeicherte Jobs / akzeptierte passende Jobs | 3 / 0 | Alle drei sind verworfene Navigations-/Themenlinks |
| Eindeutige Firmen in alten Live-Pilotversuchen | 5 | Zwei Logdateien; aktuell persistierter Store umfasst nur drei dieser Firmen |
| Kandidatencluster mit Website-Ermittlungsbedarf | 1.120 | Zentraler Akquiseengpass |
| Davon letzter Grund: Quellentyp nicht zugelassen | 1.087 | Mehr Parallelität allein löst diesen Zustand nicht |
| Davon Website-Ermittlungsfälle aus OSM | 1.044 | Hinweis und offizielle Bestätigung müssen getrennte Stufen sein |
| Sichtbare Firmenkarten | 250 | 229 gespeicherte Firmen sind im HTML nicht erreichbar |

Die bisherige Coverage kann `target_inventory_gap_to_1000=0` zeigen, weil sie 2.264 Bestands-/Zielgebiet-Kandidaten addiert. Diese Rechnung misst ein anderes Ziel. Auch 662 bereits zugeordnete Queue-Kandidaten sind keine 662 zusätzlichen Firmen. Für die Zahl vollständig untersuchter Arbeitgeber besteht derzeit kein verlässlicher Vertrag; der Wert bleibt **unbekannt**, statt technische SUCCESS-Werte umzudeuten.

## Kritische fachliche Befunde

1. **Verschiedene Stellen können dieselbe Identität bekommen.** Die Live-ID-Heuristik liest aus `https://jobs.example.com/job/123` und `/456` jeweils `s.example.com`. Der Hostteil wird als starke Job-ID behandelt. Das kann verschiedene Stellen verschmelzen; im Store ist ein entsprechender Siemens-Wert vorhanden. Beleg: `src/JobAgent.LiveScan.psm1:559`, Repro 2 im Matchingbericht.
2. **Teilscans können Stellen fälschlich entfernen.** Ein erfolgreicher Detailabruf ergibt SUCCESS, obwohl ein zweiter Abruf 503 liefert. Die Statusmaschine akzeptiert SUCCESS/NONE und sogar PARTIAL/NO_JOBS_FOUND als Entfernungsvoraussetzung. Vollständigkeit muss bis zum Statusübergang ausdrücklich belegt werden. Beleg: `LiveScan.psm1:665`, `StatusMachine.psm1:380`; Repro 3.
3. **Aktualisierte Jobs behalten alte Ablehnungen und Filterfelder.** Ein eingehender MATCH/A/HYBRID/FULL_TIME-Treffer bleibt beim Update REJECTED/UNRATED/UNKNOWN. Dadurch hilft auch eine nachträgliche Verbesserung des Matchers bestehenden Jobs nicht zuverlässig. Beleg: `StatusMachine.psm1:280`; Repro 4.
4. **Das Suchprofil verliert angefragte Rollen und akzeptiert falsche Orte.** IT Manager in Freising und IT Lead in München werden im reproduzierten Fall trotz Personalführung abgelehnt. Eine starke IT-Leitungsrolle in Hamburg wird MATCH, weil Hamburg als UNKNOWN behandelt wird. Titel, tatsächliche Verantwortung und belegter Stellenort müssen eigenständige Kriterien sein. Beleg: `Classification.psm1:106`, `:198`; Repro 1.
5. **Der aktuelle Live-Adapter durchsucht keine vollständigen Stellenlisten.** Zehn frühe Navigationslinks können den relevanten elften IT-Manager-Link verdrängen; standardmäßig werden nur fünf Details geladen. Ein Linktitel und die ersten 500 Zeichen Seitentext reichen nicht für Jobidentität, Standort und Verantwortung. Generische Karriere-/FAQ-/Bereichsseiten werden als Rohjobs persistiert. Beleg: `LiveScan.psm1:438`, `:549`, `:635`.
6. **Der normale Daily-Einstieg verlangt Testdaten.** `tools/Invoke-JobAgentDailyRun.ps1:30` verlangt FixturePath; Livebetrieb ist eine separate Pilotlane. Für dauerhafte 1.000er-Abdeckung fehlt die durchgehende produktive Ausführung einschließlich Resume, Vollständigkeitsnachweis und quellenkonformer Wiederholung.

Diese Befunde sind reproduzierbar oder direkt am Code belegt. Die vorhandenen grünen Funktionstests widerlegen sie nicht, weil die entsprechenden Randfälle fehlen. Deshalb werden Datenkorrektheit und eindeutige Scanbelege zuerst geschlossen; Vorbereitung der Akquise kann parallel laufen.

## Schnellere Firmenakquise

Die größte kurzfristige Wirkung liegt in der bestehenden Queue, nicht im Sammeln weiterer bloßer Firmennamen. Der Regionalimport erhält derzeit kein nutzbares unverifiziertes Websitefeld. Die folgende Domainermittlung verwirft Sekundärhinweise, statt eine darin genannte mögliche Website unabhängig offiziell zu prüfen. Die Verifikationsgrenze ist sinnvoll; die Verbindung zwischen Hinweis und Prüfung fehlt.

Der neue JA-027-Slice erhält Websitehinweise mit Provenienz, prüft die offizielle Firmen-/Standortidentität, folgt belegten Karriere-/ATS-Pfaden und übernimmt Ergebnisse atomar. Mehrdeutige Namen bleiben Reviewfälle. Ein begrenzter Workerpool mit Host-/ATS-Limits, Timeout, Retry-After, Backoff, Cache und Resume bearbeitet größere Batches; ein einzelner Writer hält Store und Queue konsistent. Der derzeitige Store-Lock umfasst lange serielle Netzläufe. Er muss auf kurze abgesicherte Schreibphasen reduziert werden, bevor parallele Jobs produktive Daten aktualisieren.

Die bisherige Arbeitsweise mit 53 offiziellen Feed-Dateien und insgesamt 408 Zeilen, meist zwei bis 16 Firmen je Welle, verursacht viel Koordination. Sie wird durch einen wiederaufnehmbaren Batch mit zunächst 100 Kandidaten als Benchmark ersetzt. Vier globale Worker sind eine Startannahme, keine gemessene optimale Einstellung. Erst danach sind Aussagen zu Netto-Neuaufnahmen pro Minute, P50/P95 und Restdauer belastbar.

Als regionale Recherchebasis bietet Munich Startup eine nach Namen, Branche und Standort gegliederte Startup-Karte; die Stadt München verweist zusätzlich auf ihre Wirtschaftsförderungs- und Branchenangebote. Beides sind Ansatzpunkte für Discovery, kein Beleg für freie IT-Leitungsstellen und keine pauschale Erlaubnis für Massendownloads. Bereits erlaubte lokale Quellen bleiben zuerst zu nutzen. Quellen: [Munich Startup Ecosystem](https://www.munich-startup.de/en/ecosystem/), [Wirtschaft und Gewerbe der Stadt München](https://stadt.muenchen.de/buergerservice/wirtschaft.html).

## Externe Karriere- und Rollenstichprobe

Abrufdatum: 05.09.2026. Die Tabelle unterscheidet lesbare Originalinhalte, technische Grenzen und konkrete Rollenhinweise. Portalfehler des Recherchetools beweisen keine Nichterreichbarkeit beim Arbeitgeber.

| Arbeitgeber / Primärquelle | Beobachtung | Konsequenz für JobAgent |
|---|---|---|
| [Mynaric Karriere](https://mynaric.com/careers/all-open-positions/) und [IT Lead](https://mynaric.jobs.personio.de/job/2391308) | Offizielle Firmenkarriereseite bindet das Personio-Portal als iframe ein. Detail nennt München, Führung des IT-Teams, Verantwortung für IT-Betrieb/Strategie und Budget. | Konkreter fachlich passender Reviewtreffer; offizieller ATS-Zusammenhang nachvollziehbar. iframe und Rollenfamilie IT Lead müssen erkannt werden. Nicht in den Store importiert. |
| [casavi IT Manager](https://casavi.jobs.personio.de/job/2741063?language=de) | Detail nennt München und Verantwortung für die interne IT; zugleich operativer Support. Die [Firmenkarriereseite](https://casavi.com/de/karriere/) zeigte eine technische Verifikationsseite. | Interessanter Kandidat; disziplinarische Führung und die ausgehende offizielle ATS-Zuordnung bleiben in diesem Review ungeklärt. Keine automatische Aufnahme als offiziell verifizierter Match. |
| [BMW Group Karriere](https://www.bmwgroup.jobs/de/en.html) | Suchfeld sowie Filter für Ort, Tätigkeitsfeld und Einstiegsart; Inhalte enthalten dynamische Ergebnis-/Leerzustände. | Ein gelesener HTML-Leertext beweist keinen vollständigen Nulltreffer. Ergebnislisten/Filter/Pagination gesondert auswerten. |
| [Allianz Karriere](https://careers.allianz.com/global/en) | Globale Karriereübersicht mit Weiterleitung und Themeninhalten. | Karriereentwicklung und andere Themenlinks von Einzelstellen unterscheiden; Standort nicht aus Konzernsitz übernehmen. |
| [HSWT Stellenangebote](https://www.hswt.de/arbeiten-an-der-hswt/stellenangebote) | Suchfeld, Bereichs-/Ortsfilter und Freisinger Campusangabe. Der gelesene Inhalt enthält einen Nullergebniszustand. | Arbeitgeberort und Stellenort trennen; aus der Textansicht allein keine abgeschlossene Suche oder Abwesenheit passender Stellen ableiten. |
| [SWM Karriere](https://www.swm.de/karriere) | Karriere-Landingpage führt unter anderem zu IT-Expert*innen als Tätigkeitsbereich. | Bestätigt am realen Inhalt, warum ein Bereichslink keine konkrete IT-Leitungsstelle ist. |
| [Flughafen München Karriere](https://munich-airport.de/karriere-7833198) | Recherchetool meldet Internal Error. | Offen/technisch nicht geprüft; weder kein Job noch vollständiger Scan. |
| [Siemens Energy Jobs](https://jobs.siemens-energy.com/) | Recherchetool meldet Internal Error. | Derselbe Fehlervertrag; kein Umgehen von Schutzmaßnahmen. |

Für Freising wurde in dieser begrenzten Stichprobe keine konkrete aktuelle Zielstelle offiziell bestätigt. Das ist keine Aussage, dass dort keine passende Stelle existiert. Der Mynaric-Treffer zeigt dagegen unmittelbar, dass ein offizieller IT-Lead-Treffer außerhalb der bisher akzeptierten Jobdaten vorhanden ist.

## UI: Was logisch ist und was fehlt

Positiv: ruhige Firmenkarten, gut lesbare Schrift, keine globale horizontale Überbreite in den vier geprüften Viewports. Technische Details sind einklappbar. Offizielle Links haben `noopener noreferrer`; der erste Karrierelink ist mit Tab erreichbar und hat sichtbaren Browserfokus. Die Berichte funktionieren ohne externe Laufzeitbibliotheken.

Die entscheidenden Bedienprobleme:

- **Kein Produkteinstieg:** `/` liefert ein Verzeichnislisting statt Jobs/Firmen/Prüfstatus. Der Server ist auf Loopback konfiguriert; daraus wird keine öffentliche Exposition behauptet.
- **Keine Suche:** Beide HTML-Seiten enthalten null Suchfelder, Selects, Buttons oder Navigation. Die Firmenliste endet alphabetisch bei KONUX; nachfolgende Firmen bleiben unerreichbar. Das Limit 250 ist nur tief in der technischen Tabelle erklärt.
- **Zu lange Liste:** Coverage ist am Desktop rund 30.618 px hoch, bei 800 px rund 46.681 px und bei 390 px rund 54.490 px. Der Diagnosezugang liegt erst darunter. Filter plus Pagination müssen vor dem Rendering auf dem gesamten Bestand arbeiten.
- **Widersprüchliche Statusaussage:** aquabench zeigt gleichzeitig „Karriere-URL verifiziert“ und einen Hinweis auf fehlende offizielle Verifikation. 39 Firmen teilen den Statuskonflikt Karriereverifikation/manueller Review. Ein gemeinsamer effektiver Evidenzstatus muss Badge, Link und Kennzahl steuern.
- **Irreführende Frische:** Alle 30 im Snapshot als FRESH markierten Firmen wurden noch nie gescannt. „Aktuell“ bezeichnet dort Import-/Verifikationsfrische. Websiteverifikation, letzter erfolgreicher Stellencheck und Reporterstellung benötigen getrennte Datumsangaben.
- **Daily-Report ist eine breite Tabelle:** 18 Spalten, in Änderungslisten 19; auf 390 px stehen 1.360 px Tabelleninhalt in etwa 325 px Containerbreite. Der Überlauf ist technisch gekapselt, Kerninformationen verlangen trotzdem horizontales Scrollen. Auf dem Smartphone verdrängen zunächst Statistikblöcke die Stellen.
- **Testdaten sind nicht klar markiert:** Alpha/Beta und example.invalid stehen unter dem normalen Daily-Report-Titel. Ein sichtbares Fixturebanner verhindert Verwechslung mit realen Treffern.
- **Falsche Bedeutung von „aktive passende Stellen“:** Der KPI zählt nur unveränderte aktive Jobs; NEW und UPDATED fehlen. Eine Gesamtzahl aller offenen passenden Stellen muss zusätzlich ausgewiesen werden.

Sollstruktur: **Stellen → Firmen → Prüfstatus**. Stellenkarten zeigen Rolle, Arbeitgeber, tatsächlichen Arbeitsort, Arbeitsmodell, Prüftag, kurze Passungsbegründung und offiziellen Detail-Link. Die Firmenansicht zeigt Karrierebeleg, letzten Stellenscan und nächste Aktion. Filter: Rolle/Text, München/Freising/Umkreis, Firma, Arbeitsmodell, Aktualität und Passung; unbekannte Daten bleiben erkennbar. Radius nur auf belegten Geodaten. Filter kombinieren, zurücksetzen und über alle Seiten anwenden; Nulltreffer unterscheiden von „noch nicht geprüft“.

Bindende Screens: [Coverage Desktop](../../doc/roadmap-screenshots/UI-001-review-20260905-coverage-1366.png), [Coverage Smartphone](../../doc/roadmap-screenshots/UI-001-review-20260905-coverage-390.png), [Daily Smartphone](../../doc/roadmap-screenshots/UI-001-review-20260905-daily-fixture-390.png), [Statuswiderspruch](../../doc/roadmap-screenshots/UI-001-review-20260905-status-conflict.png). Alle vier Breiten sind unter `doc/roadmap-screenshots/` dauerhaft abgelegt.

## Validierung und Betriebsgrenzen

| Prüfung | Ergebnis | Aussage |
|---|---|---|
| Classification, LiveScan, StatusMachine, SourceAdapters, Report | PASS, jeweils Exit 0 | Fünf bestehende funktionsbezogene Suites; die dokumentierten Repros zeigen fehlende Akzeptanzfälle |
| HtmlAudit | PASS, Exit 0 | Render-/Stringcontract; kein vollständiger Browser-Usabilitytest |
| HtmlViewportAudit | FAIL, Exit 1 | Lokaler Chrome-GPU-Prozess bricht beim ersten Screenshot ab; weitere Testviewports dieses Laufs nicht ausgeführt |
| Separater echter Browserreview | Durchgeführt, 1920/1366/800/390 px | Produktfehler per DOM, Interaktion und Screens nachgewiesen; keine bestandene Produktabnahme behauptet |
| CI self-check zu Beginn | FAIL, 5 Befunde | Roadmap-Pin, Checkpoint und Handoff inkonsistent |
| CI self-check nach Sync | FAIL, 1 Befund | Checkpoint/Handoff konsistent; bestehender Roadmap-Pin-Konflikt bleibt für CI-001 offen |
| Devserver über CI starten | FAIL | Gesperrtes Log; bestehender Server trotzdem im Browser erreichbar, kein erfolgreicher Neustart behauptet |
| SonarQube API | UP | Dienst läuft; keine neue Codeanalyse und kein Quality-Gate-Pass |
| Supertest | NOT RUN | Review/Roadmap-Slice; kein Produktpunkt vollständig umgesetzt |

Der fehlgeschlagene Viewporttest lässt eine alte Summary mit `status=ok` liegen. Sie ist kein Nachweis für diesen Lauf. Sein historischer Screenshot wurde bytegleich wiederhergestellt; aktuelle Reviewbelege sind kanonisch unter `doc/roadmap-screenshots/UI-001-review-20260905-*.png` abgelegt. Bytegleiche temporäre WEB-20260905-Kopien wurden zur Übergabe entfernt. Der reguläre Verify-/Sonarpfad referenziert noch Gradle. Das ist als CI-001 priorisiert; für diesen Dokumentationsreview werden weder Bootstrap-Runtime noch Pins pauschal geändert.

Die abschließende Roadmap-/Todo-/Checkpoint-/Handoff-Verifikation und STP-Ausgabe stehen in [Abschlussnachweis](2026-09-05-validation.json). Der alte Plan und der alte unvollständige Checkpoint sind vor der Bereinigung gesichert. Historische Roadmap-Abschlüsse werden nicht nachträglich als aktuelle Vollständigkeitsbelege umgedeutet.

## Priorisierte Umsetzung

Die Roadmap enthält sechs vollständige Punkte mit Abhängigkeiten, Aufwand, Dauer, Score, Risiken, Tests und Meilensteinen:

| Reihenfolge | Punkt | Aufwand/Dauer bei einem Entwickler | Score | Meilenstein / Parallelisierung |
|---|---|---|---:|---|
| 1 | JA-040: korrekte Jobidentität, Teilscans, Updates und Zählvertrag | 2–3 PT / 2–3 Arbeitstage | 100 | M1; parallel zu CI-001 und Akquisevorbereitung |
| 2 | CI-001: verlässliche Projekt-/Browser-/CI-Nachweise | 1–2 PT / 1–2 Arbeitstage | 99 | M1; unabhängig von Adapterentwicklung |
| 3 | JA-027: automatisierte verifizierte Firmenakquise | 3–5 PT / 3–5 Arbeitstage plus externe Restfälle | 98 | M2; nach M1, parallel zu JA-041 |
| 4 | JA-041: vollständige ATS-/Stellenextraktion und Zielrollen | 3–5 PT / 3–5 Arbeitstage | 95 | M2; Entwicklung mit bestehendem Firmenbestand |
| 5 | UI-001: vollständige filterbare Stellen-/Firmenansicht | 2–3 PT / 2–3 Arbeitstage | 90 | M3; ab stabilem Datenvertrag parallel zu M2 |
| 6 | JA-042: belegter 1.000er-Live-Lauf und Wiederholung | 1–2 PT plus gemessene Netz-/Retrydauer | 88 | M3; nach den vorherigen Ergebnissen |

Planannahme: ein Entwickler/Agent, vorhandener Windows-/PowerShell-/JSON-Stack, keine zugesagte Such-API, keine zusätzliche Teamkapazität und kein fester Endtermin. Gesamtaufwand 12–20 Personentage; 3–5 Arbeitswochen sind eine grobe Kalenderannahme, keine Zusage für die extern abhängig erreichbare Firmenzahl. Schnelle Akquise und sichere Suche werden gemeinsam gemessen; eine höhere Kandidatenzahl allein gilt nicht als Fortschritt auf das 1.000er-Scanziel.
