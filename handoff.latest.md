# Handoff latest

Stand: 2026-09-06T12:40:30.047+02:00. Reiner Planungsabschluss vor Commit/Push; die Gitfelder im JSON sind der STP-Snapshot vor diesem Abschluss-Commit.

## Auftrag und Ergebnis

Der Nutzer hat ausschließlich zuerst detaillierte Roadmap-Punkte angefordert, danach STP, sauberen Worktree, Stage, Commit und Push. Zusätzlich bindend: alle erfassten Firmen sowie entdeckte Website-/Jobs-/Karriere-/Stellenangebote-/ATS-URLs dauerhaft speichern. Keine Akquise oder Implementierung in diesem Abschluss.

`Roadmap.md` enthält JA-027 mit genau drei detaillierten checkboxbaren Arbeitspaketen, je Beschreibung, Scope, Ist-Stand, Abhängigkeiten, Aufwand/Dauer, Priorität, drei Umsetzungsschritten, messbarer Done/Evidence, konkreten vorhandenen Funktionstest-Commands, Audit und Abschlussgate. Reihenfolge nach Abhängigkeiten; keine zusätzlichen Top-Level-Todos. `Roadmap_index.md` und der aktive Todo-/Checkpointzustand sind synchronisiert.

## Nächster verbindlicher Hotspot

1. JA-027.1: dauerhafte Erfassung vor weiteren schreibenden Quellenrefreshes umsetzen. Firmen ohne Website/offizielle Bestätigung bleiben gespeichert; alle entdeckten URLs samt Herkunft, Prüfstatus und Historie ebenso. Keine Löschung bei leeren Portalen, Quellenrefresh, Ablauf, 404/410 oder Timeout. `New-ToolMergedHintStore` überspringt derzeit alte Hinweise aus ersetzten Quellen; diesen Verlustpfad mit versionierter Migration, Backup, serieller Schreibphase und Restore-Tests absichern.
2. JA-027.2: vorhandene Registry-/Jobbörsen-/Register-/Regionalbestände nutzen und neue Quellen gezielt recherchieren. Jobbörsen, Register, Suchmaschinen, OSM und weitere Sekundärquellen dürfen Firmen-/Websitehinweise liefern; offizielle Verifikation ist ein nachgelagerter Schritt. Im Plan stehen vorhandene Quellen-IDs, eine Suchmatrix und mindestens sechs zu prüfende neue Anbieter-/Datensatzansätze. Read-only-Inventur parallel zu JA-027.1; neue Imports erst nach sicherer Aufbewahrung.
3. JA-027.3: Firmenwebsites unabhängig bestätigen, tatsächlich verlinkte Karriere-/Jobs-/Stellenangebote-/ATS-URLs dauerhaft übernehmen, 100 reale Kandidaten über hostbegrenzte Batches messen und bis 1.000 gültig belegte Karrierearbeitgeber fortführen. Domain-only/Fixture/Alias nicht mitzählen. Einzelresultat-Resume, tatsächliche Hostlimits einschließlich Redirect/ATS und Netto-/Request-/Quantilmetriken noch nachweisen.

JA-027 bleibt `TD-0041` / `in-progress`. Sein Akquiseabschluss verlangt 1.000 belegte Karrierearbeitgeber, nicht bereits 1.000 vollständige Stellenscans. Diese gehören zu JA-042. JA-041 darf mit vorhandenen verifizierten Quellen parallel beginnen; ein vollständiger JA-027-Abschluss ist keine Voraussetzung für Entwicklung/Pilot. UI-001 und JA-042 bleiben offen. Kein Roadmap-Punkt wurde archiviert.

## Bestandsbefund und Korrektur früherer Übergabe

32 registrierte Quellen, 1.790 Hinweise aus 26 Quellen, 1.785 Queueeinträge: 662 VERIFIED, 1.122 MANUAL_REVIEW_REQUIRED, 1 RETRY_EXHAUSTED, 0 PENDING; 479 gespeicherte Firmen und 439 JobSources. Die fünf Hinweise ohne Queueeintrag müssen einzeln erklärt werden. Kleine Jobbörsen-/Registerbestände auf Fixtureherkunft prüfen.

Die frühere pauschale Aussage „keine nutzbaren Quellen“ ist nicht belegt. Keine gespeicherten PENDING-Einträge ist ein Queuezustand und kein Nachweis ausgeschöpfter Quellen. Registry, Hinweise, rekonstruierte Eligibility und tatsächliche Websitehinweise gemeinsam prüfen; keine Sammelrücksetzung aller Reviewfälle. Aktuelle externe Verfügbarkeit wurde in diesem Planungsauftrag nicht recherchiert und wird nicht behauptet.

Commit `4d797ee` enthält die vorhandene Batchengine; deren frühere grünen Funktionstests sind historische Evidence. Ein running/completed-Laufcheckpoint allein beweist noch keinen verlustfreien Wiederanlauf einzelner Ergebnisse. Die vorhandene Auswahlbegrenzung garantiert nicht automatisch 100 bearbeitete Kandidaten oder ein gemeinsames Redirect-/ATS-Hostlimit. Der neue Plan benennt diese Nachweise ausdrücklich.

## Verifikation dieses Abschlusses

- Roadmapstruktur geprüft: genau drei JA-027-Unterpunkte mit allen Pflichtfeldern und je drei Umsetzungsschritten; aktive Reihenfolge und ein aktives Todo konsistent.
- Alle zwölf referenzierten Testdateien und 21 konkreten bestehenden Quell-/Dokumentpfade vorhanden; geplante Evidence ist als künftig zu erzeugen markiert.
- `git diff --check` ohne Fehler; `cmd /c .\ci.cmd stp` mit Exit 0.
- Produktiver Store, Hinweise, Queue und Quellenregistry unverändert; SHA-256 vor/nach in `handoff.latest.json`.
- Supertest nicht ausgeführt: für diesen Planungsabschluss vom Nutzer freigestellt, kein behaupteter erfolgreicher Testlauf. Keine Anwendungsfunktion geändert, daher keine Anwendungs-/Browser-/Netzwerktests.
- Im generierten STP übernommene ältere Sonar-/Route-Digests bleiben im JSON als Historie erhalten; Sonarstatus not-supported ist kein Analyseerfolg.

Der nächste Chat arbeitet nach `Roadmap.md` an JA-027.1 weiter. Dieser Chat endet nach dem beauftragten Commit und Push.
