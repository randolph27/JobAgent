# UI-Codeanalyse: Firmen-Coverage und Daily Report

Stand: 2026-09-05, Abschluss der Funktionstests gegen Git-HEAD `ce6e8ba48016e91933c4ad58311bd9e898fb3ba0`.

Scope: read-only Produkt- und Code-Review von `tools/Measure-JobAgentCompanyCoverage.ps1`, `src/JobAgent.Report.psm1`, `tests/Test-JobAgentReport.ps1`, `tests/Test-JobAgentHtmlAudit.ps1`, `tests/Test-JobAgentHtmlViewportAudit.ps1`; zur Ursachenpruefung gezielt `src/JobAgent.Coverage.psm1`. Keine Produktdatei und kein produktives Coverage-Artefakt wurde veraendert oder regeneriert. Der Viewport-Funktionstest erzeugte seine normalen Fixture-/Logdateien.

Datengrundlage: `logs/jobagent/company-coverage-20260905-123803.json`, erzeugt um `2026-09-05T12:38:03.998Z`. Browserbeobachtungen stammen separat vom Root-Agent; dieser Teilreview verwendet keine Browsertools.

## Befunde nach Wirkung und Abhaengigkeit

### UI-01 — Hoch: Das Nutzerziel ist im Einstieg nicht messbar

Der Einstieg nennt 479 Unternehmen, 433 verifizierte Karriere-URLs und 46 verifizierte Firmendomains. Der Snapshot weist gleichzeitig nur 2 Firmen mit letztem erfolgreichen Scan, 1 mit fehlgeschlagenem Scan und 476 nie gescannte Firmen aus. Alle 479 sind nach Scanalter faellig oder ungescannt. Das sind unterschiedliche Stufen; die Verifikation eines Karrierepfads ist kein Nachweis, dass die Stellenliste vollstaendig untersucht wurde. Der KPI `target_inventory_gap_to_1000=0` beruht auf 2264 Bestands-/Zielgebiet-Kandidaten, nicht auf 1000 untersuchten Firmenwebseiten.

Code: `tools/Measure-JobAgentCompanyCoverage.ps1:617` bis `:630`; `src/JobAgent.Coverage.psm1:435`, `:440`, `:443`. Im sichtbaren Einstieg fehlen gepruefte Firmen, erfolgreich untersuchte Stellenlisten, Fehler, Scanzeitpunkt und Fortschritt zum eigentlichen 1000er-Ziel. Die weiter unten eingeklappte technische Quellenstatistik ersetzt diesen Produktnachweis nicht.

Akzeptanz fuer den Umsetzungsslice: Im Einstieg getrennte Zaehler fuer eindeutige Arbeitgeber, offizielle Karrierequellen, Scanversuche, erfolgreich vollstaendig untersuchte Firmen, offene/gescheiterte Pruefungen und passende aktive Stellen. Das 1000er-Ziel zaehlt eindeutige Firmen mit belegtem Untersuchungszeitpunkt und explizitem Ergebnis; Discovery-Hinweise werden dafuer nicht addiert.

### UI-02 — Hoch: 229 Firmen sind im HTML nicht erreichbar; Filter fehlen

Die Firmenkarten und die Inventartabelle rendern jeweils starr `Select-Object -First 250`. Bei 479 Firmen fehlen damit 229 Eintraege. Der Kuerzungshinweis steht erst in der technischen Inventartabelle unterhalb der Karten und verweist nur textlich auf ein JSON-Artefakt. Es gibt weder Seitennavigation noch Such-/Standort-/Statusfilter. `MaxPriorityItems` hebt dieses Limit nicht auf.

Code: `tools/Measure-JobAgentCompanyCoverage.ps1:623`, `:685`, `:686`; Markdown ebenfalls `:577`. `:640`, `:645`, `:651`, `:656`, `:676`, `:681` begrenzen weitere Listen auf 25. Die gesamte HTML-Erzeugung `:607` bis `:689` enthaelt keine `input`, `select`, `button`, `nav` oder `script`-Elemente. Der Daily-HTML-Renderer `src/JobAgent.Report.psm1:1115` bis `:1246` bietet ebenfalls keine Filter.

Root-Browserbeleg: 250 Karten, null Filter/Buttons/Navigation. Coverage-Seitenhoehe ca. 30.618 px Desktop, 46.681 px bei 800 px und 54.490 px bei 390 px; die technische Auswertung liegt nach der gesamten Kartenliste. Screenshots: `doc/roadmap-screenshots/UI-001-review-20260905-coverage-{1920,1366,800,390}.png`.

Akzeptanz: Der gesamte Bestand muss erreichbar sein, auch Treffer hinter Eintrag 250. Beschriftete Suche plus Ort/Zielgebiet, Stellenrolle, Verifikation, Scanstatus, Aktualitaet und Arbeitsmodell; kombinierbare Filter, Trefferzahl, Zuruecksetzen und verstaendlicher Leerzustand. Filter werden ueber alle Datensaetze angewendet, bevor paginiert oder virtualisiert wird. Technische Auswertung und Stellenansicht brauchen einen direkt erreichbaren Einstieg.

### UI-03 — Hoch: Verifikationsbadge und nutzbarer Link widersprechen sich

Bei aquabench zeigt der Firmenstatus `CAREER_URL_VERIFIED`, der primaere Link aber `UNVERIFIED`, `review_only=true`, `is_clickable=false`. Der Inventarstatus lautet `MANUAL_REVIEW_REQUIRED`. Das ist kein reiner Textfehler: Der Badge verwendet den Firmenstatus, die Linkentscheidung dagegen zusaetzlich den alten `discovery_source.type=DISCOVERY_HINT`.

Code: Badge in `tools/Measure-JobAgentCompanyCoverage.ps1:625`; Linkentscheidung in `src/JobAgent.Coverage.psm1:224` bis `:235`, Inventarstatus `:474`, `:488`. Im untersuchten Snapshot sind 39 Firmen gleichzeitig `CAREER_URL_VERIFIED` und `MANUAL_REVIEW_REQUIRED`. Insgesamt haben 47 als Karriere-URL/Firmendomain verifiziert markierte Firmen keinen klickbaren primaeren Link; die weiteren 8 sind `COMPANY_DOMAIN_VERIFIED`/`VERIFIED_WEBSITE_ONLY`. Die Ursache der 8 weiteren Faelle wurde in diesem Teilreview nicht einzeln untersucht.

Der Seitentitel „Arbeitgeber mit offizieller Karriereseite“ (`tools/Measure-JobAgentCompanyCoverage.ps1:617`) umfasst zudem alle Firmendomains ohne Karriere-URL. Alle Badges verwenden dieselbe gruene Gestaltung (`:615`), unabhaengig davon, ob der Zustand geprueft, offen oder widerspruechlich ist.

Akzeptanz: Ein effektiver, evidenzbasierter Verifikationsstatus steuert Badge, Link, KPI und naechste Aktion. Widersprueche sichtbar als Pruefbedarf behandeln; einen alten Discovery-Typ nicht durch ungeprueftes Freischalten umgehen. Seitentitel muss auch Firmen ohne Karrierepfad korrekt beschreiben.

### UI-04 — Hoch: „Aktuell“ bezeichnet Import-/Verifikationsfrische, nicht den Stellencheck

Die Karte zeigt allein `staleness_status` als „Aktuell“, „Abgelaufen“ oder „Refresh faellig“ (`tools/Measure-JobAgentCompanyCoverage.ps1:143`, `:625`). Dessen Basis sind `last_verified_at` oder `last_imported_at`, mit Fallbacks auf Import-/Erstellungszeit; `last_successful_scan_at` bildet separat `is_stale`. Im Snapshot sind alle 30 als `FRESH` markierten Firmen noch nie gescannt.

Code: `src/JobAgent.Coverage.psm1:90`, `:99` bis `:109`, `:443`, `:456` bis `:481`. Das betrifft die Bedeutung der Anzeige, nicht automatisch die Richtigkeit der gespeicherten Zeitwerte. Auch der Generierungszeitpunkt fehlt im Coverage-HTML; er wird nur im Markdown gerendert (`tools/Measure-JobAgentCompanyCoverage.ps1:429`).

Akzeptanz: „Website zuletzt verifiziert“ und „Stellen zuletzt erfolgreich geprueft“ getrennt mit Datum und Ergebnis ausgeben. Bei nie gescannten Firmen muss genau dies sichtbar sein. Berichtserstellungszeit ist eine dritte, getrennte Angabe und darf alte Quelldaten nicht als frisch erscheinen lassen.

### UI-05 — Mittel: „Aktive passende Stellen“ zaehlt nur unveraenderte Stellen

Die Trennung von Neu/Aktualisiert/Unveraendert verhindert Doppellisten und ist nachvollziehbar. Die Statistik `active_matching_jobs` zaehlt aber lediglich die unveraenderte Liste: Neue und aktualisierte, weiterhin aktive Stellen werden vorher ueber `changedIds` entfernt. Der sichtbare KPI bleibt „Aktive passende Stellen“.

Code: `src/JobAgent.Report.psm1:560`, `:687` bis `:694`, `:739`, `:1178`, `:1199`. Der bestehende Test hat 3 passende aktive Statuswerte (`NEW`, `ACTIVE`, `UPDATED`; `tests/Test-JobAgentReport.ps1:139` bis `:141`), erwartet fuer den KPI aber 1 (`:207`). Gruene Tests sichern damit die bestehende missverstaendliche Semantik ab.

Akzeptanz: Gesamtzahl aller aktuell offenen passenden Stellen getrennt von „unveraendert aktiv“ zaehlen; dieselbe Definition fuer Header, Filter und Liste verwenden. Die Neu-/Aenderungsabschnitte koennen zusaetzlich erhalten bleiben.

### UI-06 — Mittel: Die Stellenansicht ist fuer schnelle Entscheidungen zu breit

Die Jobtabelle hat 18 Spalten, mit Aenderung 19. Mindestbreite 1500 px, unter 800 px weiterhin 1360 px. Standort, Titel, Prioritaet, Anbieterlink, Alter, Anforderungen und Begruendung sind deshalb nicht gemeinsam auf einem Smartphone lesbar. Der bestehende CSS-Ueberlaufschutz verhindert Seitenueberlauf, beseitigt aber die horizontale Bedienlast nicht.

Code: `src/JobAgent.Report.psm1:756`, `:1140` bis `:1148`. Root-Browserbeleg: Bei 390 px Viewport ist der Tabellencontainer ca. 325 px breit, der Inhalt 1360 px; kein globaler horizontaler Seitenueberlauf. Screenshots: `doc/roadmap-screenshots/UI-001-review-20260905-daily-fixture-{1920,1366,800,390}.png`.

Akzeptanz: Stellen zuerst mit Rolle, Firma, Arbeitsort, Matchbegruendung, Aktualitaet und eindeutigem Stellenlink in einer kompakten Ansicht darstellen. Weitere Daten pro Stelle aufklappbar. Technische IDs und Adaptermetriken gehoeren in die Betriebsauswertung; gefilterte Ergebnisse und Links bleiben per Tastatur bedienbar.

### UI-07 — Mittel: Fixture-Bericht ist nicht sichtbar als Testdaten gekennzeichnet

Der Viewport-Test erzeugt Alpha/Beta-Firmen, `example.invalid`-Links und `adapter='fixture'`, rendert aber denselben Titel „JobAgent Daily-Run-Bericht“ wie reale Daten. Im Berichtskopf stehen weder klarer Fixture-Hinweis noch menschenlesbarer Laufzeitpunkt; `ScanRun` ist ein technischer Identifier.

Code: `tests/Test-JobAgentHtmlViewportAudit.ps1:56` ff., `:279` bis `:293`; `src/JobAgent.Report.psm1:1154` bis `:1167`. Der Renderer uebernimmt keine sichtbare Datenmodus-Kennzeichnung. Root bestaetigt im Browser das fehlende Fixturelabel. Der lokale Server zeigt am Pfad `/` eine Verzeichnisliste statt eines Produkteinstiegs; laut Root ist er an `127.0.0.1` gebunden. Daraus wird in diesem Review keine oeffentliche Exposition abgeleitet.

Akzeptanz: Ein klarer Produkteinstieg verlinkt Jobs, Firmenbestand und Betriebsstatus. Testdaten erhalten ein sichtbares, eindeutiges Banner; Live-/Testmodus sowie Scan- und Berichtszeit sind in Header und Artefaktmetadaten konsistent.

### UI-08 — Mittel: Bestehende HTML-/Viewport-Tests belegen die Produktbedienbarkeit nicht

`Test-JobAgentHtmlAudit.ps1:178` bis `:196` prueft Textfragmente, CSS-Ueberlaufregeln, externe Ressourcen und Links anhand einer synthetischen Daily-Report-Fixture. Das ist ein hilfreicher Rendercontract, testet aber weder die produktive Company-Coverage-Ansicht noch Filter, Pagination, Tastatur, Trefferzahlen oder Verifikations-/Frischekonsistenz.

`Test-JobAgentHtmlViewportAudit.ps1:283` bis `:337` prueft eine eigene Fixture-URL, HTTP 200, Browserexitcode, Screenshotexistenz und PNG-Dateigroesse ueber 10 KB fuer 1920/1366/800 px. Ein bestandener Lauf belegt Screenshot-Erzeugung. Er enthaelt keine DOM-Geometriepruefung, keine Assertions zu verdeckten Links oder abgeschnittenen Inhalten und keine automatische visuelle Bewertung. Ein Smartphone-Viewport fehlt.

Zusaetzlicher konkret reproduzierter Nachweisfehler: Bei Browserabbruch vor Zeile 358 bleibt ein frueheres `ja-022-viewport-audit.json` mit `status=ok` bestehen. Der aktuelle Lauf scheiterte um 19:05 Uhr, waehrend die Summary von 14:41 Uhr weiterhin `ok` enthielt. Die Summary hat keine Lauf-ID/Erstellungszeit fuer eine sichere Zuordnung. Vorhandene Screenshots werden vor erfolgreicher Neugenerierung geloescht (`:312` bis `:317`).

Akzeptanz: Funktionspruefungen mit mindestens 1001 Datensaetzen und Treffern jenseits Eintrag 250; kombinierte Filter, korrekte Zaehler, Leerzustand, URL-Vertrauen und Frischefaelle. Browserchecks auf echter Coverage-/Stellenoberflaeche bei 390/800/1366/1920 px; Kernaktionen und Geometrie pruefen. Evidence transaktional je Lauf schreiben und Fehler explizit ausweisen, damit alte gruene Artefakte nicht als aktueller Pass gelesen werden.

## Ausgefuehrte Funktionstests

| Befehl | Ergebnis | Aussage/Grenze |
|---|---|---|
| `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` | PASS, Exitcode 0, 10 gemeldete Fallgruppen | Reportsektionen, Ablehnungsfilter, Prioritaet, optionale Leerwerte, Markdown/HTML, Quellenmetriken, Linkregeln, Escaping, Leerzustand. |
| `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlAudit.ps1` | PASS, Exitcode 0, 4 gemeldete Fallgruppen | Pflichtinhalte, CSS-Ueberlaufschutz, keine externen Laufzeitressourcen, Erhalt offizieller Stellenlinks. |
| `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` | FAILED, Exitcode 1 | Fixture-HTML wurde erzeugt und ueber Port 8500 mit HTTP 200 geladen. Chrome scheiterte beim ersten Screenshot (1920 px): wiederholte GPU-Prozessabbrueche `exit_code=-1073741790`, abschliessend `GPU process isn't usable. Goodbye.` Weitere Viewports dieses Testlaufs wurden nicht ausgefuehrt. |

Fehlerlog: `output/playwright/ja-022-viewport-1920.stderr.log`. Die vorhandene maschinenlesbare Summary `logs/jobagent/ja-022-viewport-audit.json` stammt von einem frueheren Lauf und ist kein PASS-Beleg fuer diesen Test. Der durch den Test geloeschte, zuvor unveraenderte versionierte Screenshot `output/playwright/ja-022-viewport-1920.png` wurde bytegleich aus dem zu Beginn erfassten Git-HEAD wiederhergestellt; er ist historische Evidence. Fuer die aktuelle visuelle Bewertung gelten ausschliesslich die separat erzeugten `doc/roadmap-screenshots/UI-001-review-20260905-*.png`-Browserbelege des Root-Agents.

Kein Supertest: Der zugeordnete Arbeitsschritt ist Review/Roadmap; Produktakzeptanz fuer 1000 untersuchte Firmenwebseiten und die hier benannten UI-Funktionen ist nicht erreicht. Der Chrome-Startfehler ist eine Grenze des bestehenden Viewport-Testlaufs; die separat erfolgreiche Root-Browserpruefung zeigt, dass der UI-Review selbst dadurch nicht blockiert wurde.

## Erhaltene Staerken

Offizielle Stellen-/Karriere-Links sind im Daily Report vorhanden; HTML wird escaped, externe Laufzeitressourcen sind nicht erforderlich. Neu, unveraendert aktiv, geaendert, geschlossen und Quellenfehler sind getrennt. Coverage trennt intern Verifikation, Scanstatus, Datum und Discovery-Hinweise bereits weitgehend; die UI kann auf diesen Feldern aufbauen. Der naechste Umsetzungsschritt braucht daher eine konsistente Produktdarstellung und belastbare Funktionsbelege, keine pauschale Neuentwicklung des Reportsystems.
