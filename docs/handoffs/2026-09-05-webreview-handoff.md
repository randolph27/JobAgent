# Übergabe für den nächsten Chat – Webreview und priorisierte Umsetzung

Stand: 2026-09-05. Projekt: JobAgent. Workspace: `D:\_Scripte\JobAgent`. Repository: `https://github.com/randolph27/JobAgent`, Branch `master`, Upstream `origin/master`.

## Genau hier fortsetzen

**Aktiver Punkt: JA-040, Todo TD-0051.** Als nächsten zusammenhängenden Umsetzungsslice Jobidentität, Scanvollständigkeit/Entfernung und Aktualisierung vorhandener Jobs korrigieren. Der letzte abgeschlossene Arbeitsschritt war ein umfassender Review mit Roadmap-Neuordnung, keine Implementierung dieser Produktkorrekturen.

Nicht zur alten Anweisung „nächste Welle BC mit fünf Firmen“ zurückkehren. JA-027 bleibt offen, wurde jedoch auf automatische wiederaufnehmbare Batch-Akquise umgestellt. CI-001 ist ein paralleler Grundlagenpunkt, nicht der Ersatz für den aktiven JA-040-Hotspot.

Zuerst lesen:

1. `README.md`: gemeinsamer Arbeitsvertrag; enthaltene Altprofile nicht wahllos vermischen. Das tatsächliche Projekt ist PowerShell/JSON mit lokalen HTML-Berichten, kein Gradle-/Android-Projekt.
2. `Roadmap.md`, `todo.current.md` und `handoff.latest.md`: aktuelle Prioritäten und Status.
3. [Webreview](../reviews/2026-09-05-webreview.md) sowie [Matching-Repros](../reviews/2026-09-05-matching-analysis.md).
4. Für Akquise-/UI-Arbeit zusätzlich [Akquiseanalyse](../reviews/2026-09-05-acquisition-analysis.md) und [UI-Codeanalyse](../reviews/2026-09-05-ui-code-analysis.md). Bindende Screens stehen unter `doc/roadmap-screenshots/UI-001-review-20260905-*.png`.

## Nutzerziel und belegter Istbestand

Mindestens **1.000 eindeutige Arbeitgeberkarriereseiten tatsächlich auf IT-Leiter-, IT-Lead- und IT-Manager-Stellen für München und Freising untersuchen**, mit nachvollziehbaren Filtern und möglichst schneller Firmenaufnahme. Ein gespeicherter Firmenname, Karriere-Link oder HTTP-200-Erfolg ist kein vollständiger Stellenscan. Titel und Firmensitz allein belegen weder Führungsverantwortung noch Stellenort.

Baseline des Reviews:

| Größe | Wert / Einschränkung |
|---|---|
| Firmen im produktiven Store | 479 |
| Firmen mit Karriereverifikationsstatus | 433; effektive Linkfreigabe teilweise widersprüchlich |
| Unterschiedliche nichtleere Karriere-URLs | 432 |
| JobSources im Store | 439 |
| Firmenstatus | 476 PENDING, 2 SUCCESS, 1 FAILED |
| Firmen mit erfolgreichem Scanzeitstempel | 2; historischer technischer Erfolg |
| Gespeicherte Jobs | 3, alle REJECTED; Navigations-/Themenlinks |
| Akzeptierte passende Jobs | 0 |
| Eindeutige Arbeitgeber in auffindbaren alten Live-Pilotversuchen | 5; nicht mit vollständiger aktueller Suche gleichsetzen |
| Kandidaten mit Website-Ermittlungsbedarf | 1.120 |
| Davon letzter Fehler Quellentyp nicht zugelassen | 1.087 |
| Website-Ermittlungsfälle aus OSM | 1.044 |
| Vollständig untersuchte Firmen nach belastbarem neuem Zählvertrag | Unbekannt; 1.000 nicht belegt |

Produktiver Store, Hint-Store und Queue wurden im Review nicht verändert. Baseline und SHA-256: [baseline.json](../reviews/2026-09-05-baseline.json). Die 662 schon zugeordneten Queue-Kandidaten sind keine 662 zusätzlichen Arbeitgeber. Der alte Kennwert `target_inventory_gap_to_1000=0` zählt Kandidaten und erfüllt das Nutzerziel nicht.

## JA-040: konkreter erster Umsetzungsslice

Scope: `src/JobAgent.LiveScan.psm1`, `src/JobAgent.Deduplication.psm1`, `src/JobAgent.StatusMachine.psm1`, `src/JobAgent.DailyRun.psm1`, `src/JobAgent.Coverage.psm1`, `schemas/jobagent.schema.json` und die jeweils zugehörigen Funktionstests. Bestehende Jobs und Historie erhalten; mögliche Migrationen atomar, mit Backup und Wiederanlauftest.

Vier zusammengehörige Ergebnisse:

1. **Jobidentität korrigieren.** Die aktuelle Regex in `LiveScan.psm1:559` extrahiert aus `https://jobs.example.com/job/123` und `/456` jeweils `s.example.com`. Dieser Hostteil wird als starke ID behandelt und kann verschiedene Jobs verschmelzen. IDs aus belegten ATS-Feldern oder exakt begrenzten Pfad-/Querysegmenten ableiten; ansonsten kanonische offizielle Detail-URL verwenden. Zwei unterschiedliche Jobs müssen verschieden bleiben, Tracking-/Sprachvarianten dürfen keine künstlichen Duplikate erzeugen.
2. **Vollständigkeit bis zur Statusmaschine durchreichen.** Ein erfolgreicher Detailabruf und ein zweiter 503-Abruf können zusammen `SUCCESS/NONE` ergeben. Die Statusmaschine erlaubt bei SUCCESS/NONE und PARTIAL/NO_JOBS_FOUND das Entfernen nicht gesehener Stellen. Pagination, Resultatlimits, Parserunsicherheit, Blockaden und ausgefallene Details müssen explizit unvollständig bleiben; kein REMOVED aus Teilbeobachtung. Mehrere Quellen einer Firma getrennt berücksichtigen.
3. **Aktualisierte Daten konsistent übernehmen.** `Update-JobAgentExistingJobFromRawJob` kopiert nicht alle neuen Bewertungs-/Arbeitsfelder. Ein incoming MATCH/A/HYBRID/FULL_TIME bleibt beim bestehenden Job REJECTED/UNRATED/UNKNOWN. Klassifikation, Priorität, Arbeitsmodell und Beschäftigung mit aktuellen Inhalten übernehmen; REJECTED-zu-MATCH und wesentliche Änderungen über zwei Läufe prüfen.
4. **Messvertrag implementieren.** `discovered`, `official_source_verified`, `live_attempted`, `live_complete`, `partial`, `blocked`, `no_matching_job`, `matching_jobs` getrennt zählen. Eindeutige Arbeitgeber und geteilte Portale/ATS-Mandanten unterscheiden. Nur belegte vollständige Live-Scans zählen auf 1.000; alte SUCCESS-Werte und Fixtures nicht rückwirkend als vollständig deklarieren.

Reproduzierbarer PowerShell-Code steht vollständig im [Matchingbericht](../reviews/2026-09-05-matching-analysis.md), Abschnitte 2–4. Keine neuen produktiven Massenscans vor diesen Korrekturen. Unverifizierte Websitehinweise für JA-027 können unabhängig vorbereitet werden.

Funktionsbezogene Validierung nach den jeweiligen Änderungen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDeduplication.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1
```

Diese Tests um die Repros ergänzen; bisher grüne Suites decken diese Fehler nicht ab. Akzeptanz einschließlich Schema-/Migrations-/Resume-Vertrag erfüllen, anschließend Roadmap/Todo/Handoff synchronisieren. Ein vollständiger Slice soll Implementierung, funktionsbezogene Verifikation und Abschluss enthalten.

## Weitere Prioritäten

Die verbindlichen Aufwandsspannen, Abhängigkeiten, Risiken, Scores und Meilensteine stehen in `Roadmap.md`. Aktuelle Reihenfolge und Zuordnung:

| Rang | Roadmap / Todo | Nächster Zweck |
|---|---|---|
| 1 | JA-040 / TD-0051 | Aktiver Datenkorrektheits- und Vollständigkeitsslice |
| 2 | CI-001 / TD-0052 | Roadmap-Pin, Prozess-/Porterkennung und wahrheitsgemäße CI-/Browser-/Sonar-Nachweise; parallel zu JA-040 |
| 3 | JA-027 / TD-0041 | Websitehinweise mit Provenienz erhalten, unabhängig offiziell verifizieren, Workerpool/Hostlimits/Retry/Resume, atomarer einzelner Writer; größere Batches statt Minifeeds |
| 4 | JA-041 / TD-0053 | Regulären Live-Einstieg, vollständige Listen/ATS/Pagination/iframe, strukturierte Details und IT-Lead-/Manager-/Standortregeln |
| 5 | UI-001 / TD-0054 | Alle Firmen/Stellen erreichbar; Suche, kombinierte Filter, Pagination, klare Live-/Fixture-/Frischekennzeichnung |
| 6 | JA-042 / TD-0055 | Tatsächlichen 1.000er-Lauf samt Zeitfenster, Quelle, Vollständigkeit und Wiederholungsnachweis durchführen |

Weitere konkrete Repros für JA-041: IT Manager in Freising und IT Lead in München werden mit Personalführung REJECTED/40; starke IT-Leitung in Hamburg wird MATCH/84. Zehn frühe Job-/Karrierelinks verdrängen einen passenden elften Link; maximal fünf Detailabrufe und beliebige erste 500 Zeichen Seitentext sind kein vollständiger Scan. Der normale `Invoke-JobAgentDailyRun.ps1`-Einstieg verlangt noch FixturePath.

Akquise: RegionalDiscovery verwirft nutzbare unverifizierte Websitefelder. Website-Ermittlung lässt überwiegend nur offizielle Evidenzklassen zu und blockiert damit vorhandene Sekundärhinweise vor unabhängiger Zielprüfung. Hinweis und Beweis als getrennte Stufen erhalten, keine pauschale Absenkung der offiziellen Verifikation. 53 manuelle Feeddateien mit 408 Zeilen dokumentieren den bisherigen hohen Koordinationsaufwand. Durchsatz zunächst anhand 100 Kandidaten messen; vier globale Worker sind eine Startannahme, keine bewiesene optimale Parallelität.

UI: 250 von 479 Firmen sichtbar, letzte Karte KONUX; keine Suche/Filter/Pagination. 39 Firmen haben widersprüchliche Karriereverifikation/Reviewanzeige. Alle 30 als FRESH markierten Firmen im Snapshot wurden noch nie gescannt. Daily-Report hat 18/19 Spalten, Smartphone-Statistik verdrängt die Stellen, Testdatenbanner fehlt. Sollnavigation: Stellen, Firmen, Prüfstatus.

## Ausgeführte Prüfungen und offene Betriebsbefunde

Der Review führte sechs bestehende funktionsbezogene Suites erfolgreich aus: Classification, LiveScan, StatusMachine, SourceAdapters, Report und HtmlAudit. Ihr PASS ist kein Beleg, dass die neu gefundenen Produktfehler nicht existieren.

`Test-JobAgentHtmlViewportAudit.ps1` scheiterte mit Exit 1 am Chrome-GPU-Prozess. Die alte Summary blieb dabei grün liegen und darf nicht als aktueller Testpass interpretiert werden. Der separat durchgeführte echte Browserreview in 1920/1366/800/390 px war möglich; aktuelle Screens liegen ausschließlich unter `doc/roadmap-screenshots/UI-001-review-20260905-*.png`. Bytegleiche temporäre WEB-20260905-Kopien wurden vor Commit entfernt.

Self-check wurde im Review von fünf Befunden auf **einen offenen Befund** reduziert: `immutable_modified: Roadmap.md`. Der alte Pin behandelt den aktiven Plan als unveränderlich. Änderungen sind vom Nutzer ausdrücklich beauftragt; den Pin nicht blind neu setzen, keine zentrale Runtime/README beiläufig ändern. Korrektur gehört zu CI-001. Checkpoint/Handoff waren zum Reviewabschluss konsistent.

Der Devserver wurde nur über `ci.cmd` angesprochen. Start meldete gesperrtes `logs/devserver/devserver.log`, obwohl der vorhandene Server im Browser auf 8500 antwortete; CI meldete zunächst `listening=False` und entfernte die veraltete PID-Datei. Keine erfolgreiche Neuanlage behaupten und keine zweite Instanz blind starten. Browserzugriff auf bestehende Reports war erfolgreich.

SonarQube auf 9000 war per API UP. Es gibt keine neue Sonar-Codeanalyse/Quality-Gate-Abnahme. `verify`/`sonar` referenzieren noch Gradle; das Projekt besitzt hier keinen passenden Wrapper. Tokens niemals in Logs/Handoff/Git ausgeben.

```powershell
.\ci.cmd devserver-status
.\ci.cmd devserver-start
.\ci.cmd self-check
.\ci.cmd route-check
.\ci.cmd stp
```

Die Befehle sind Bedienreferenzen, keine Aufforderung zu blindem Neustart oder Wiederholung bekannter Fehler. Bei bereits erreichbarem 8500-Server dessen Zustand zuerst klären. Aktuelle Betriebszustände im neuen Chat erneut read-only feststellen.

## Supertest, Rotation und Gitabschluss

**Aktuelle Nutzeranweisung für diese Übergabe:** „wenn supertest nicht angefragt wurde, gilt er als erledigt.“ Es wurde kein Supertest angefragt und keiner ausgeführt. Die Anforderung gilt für diesen Abschluss als durch Nutzeranweisung erfüllt; kein erfundener Exitcode oder Testpass. Die dokumentierten fehlgeschlagenen Funktionstests bleiben davon unberührt. Bei späterer Produktumsetzung gelten die dann aktuellen Nutzer-/Roadmap-Testregeln.

Keiner der sechs Produktpunkte ist vollständig implementiert oder abgenommen. Deshalb wird keiner als erledigt archiviert. Der abgeschlossene Review ist ein eigenes Dokumentationsartefakt. Die alten JA-027-/UI-001-Fortschritte stehen unverändert im [vorherigen Plan](../reviews/2026-09-05-roadmap-before.md); dessen Hash ist in Baseline und Archiv verankert. Historisch wiederverwendete IDs im alten Archiv nicht umschreiben.

Dieser Handoff wird mit Review, Roadmap, State und neun kanonischen Screens gemeinsam versioniert. STP wird vor dem Commit ausgeführt; der darin gespeicherte Git-Snapshot beschreibt ausdrücklich den Stand vor diesem Abschlusscommit. Den endgültigen Commit/Pushstand im neuen Chat mit Git feststellen:

```powershell
git status --short
git log -1 --oneline
git rev-list --left-right --count HEAD...origin/master
```

Keine automatische Bewerbung, keine Kontakte anschreiben, keine erfundenen Daten, kein Umgehen von Schutzmechanismen. Webseiten-/ATS-Hinweise bleiben unverifiziert bis zum offiziellen Beleg; Stellenort nicht aus Firmensitz ableiten. Große abschließende Slices bevorzugen, keine Nebenrefactors. Devserver und Sonar nur über `ci.cmd` starten.
