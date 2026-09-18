# Uebergabe-Details

Stand: 2026-09-18T19:10:15+02:00. Der maschinelle Kurzstatus steht in `handoff.latest.json` und `handoff.latest.md`. Aktiver Todo-Punkt: `TD-0077`; Roadmap-Anker: `JA-049`.

## Abgeschlossen und rotiert: JA-055

`JA-055 Unpassende Stellen und Arbeitgeber reversibel aus der persoenlichen Anzeige ausblenden` ist fachlich abgeschlossen und vollstaendig nach `Roadmap_archive.md` rotiert. `TD-0082` ist aus `todo.state.json` entfernt und im `todo.master.index.json` als `done` registriert.

- Die Ausblendung ist browserlokal in `jobagent-user-state/v2` implementiert. `hidden_jobs` und `hidden_companies` speichern stabile IDs, Boolean, optionalen Grund (`ROLE`, `LOCATION`, `CONDITIONS`, `EMPLOYER`, `OTHER`), maximal 500 Unicode-Codepoints Text und UTC-Aenderungszeit.
- Die effektive Sichtbarkeit ist Job ODER Firma. Das Einblenden eines Jobs hebt die Firmenausblendung nicht auf; die UI benennt den weiter wirkenden Arbeitgebervorrang. Gleiche Namen mit verschiedenen IDs bleiben unabhaengig.
- Die Stellenansicht nutzt `visibility=visible|hidden|all`, sichtbare/ausgeschlossene distinct Zaehler, eine Verwaltungsansicht, sofortiges Rueckgaengig und einen Reset, der nur Filter zuruecksetzt. Favoriten, Bewerbungsdaten, Notizen und Termine werden nicht geloescht.
- Import/Export/Merge, v1-Migration, Textgrenzen, Quota-Rueckfall und neue Stelle derselben ausgeblendeten Firma sind durch den UserState-Vertrag belegt. Private Ausblendgruende werden nicht in URL oder Reportstore geschrieben.
- Die isolierte Browserfixture weist 262 sichtbare und 2 ausgeschlossene Stellen nach. Sie prueft Grund/Text, Rueckgaengig, Firmenvorrang, Reset, Verwaltungsansicht, keinen fachlichen Bediennetzwerkzugriff und die Pflichtviewports 390/800/1366/1920.

Evidence:

- `docs/reviews/JA-055-acceptance.md`
- `logs/jobagent/JA-055/visibility-cases.json`
- `doc/roadmap-screenshots/JA-055-hidden-management-390.png` mit SHA-256 `36AD4EE1826776F78871AE399F8B82FBD5C74DDA1BE1D934A043F0B274DE266D`

Verifikation:

- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1 -WriteInventory` -> Exit 0; Funktionsinventar: 601 Eintraege
- `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1` -> Exit 0
- `./ci.cmd supertest` -> Exit 0; 32/32 bestanden, 0 fehlgeschlagen, 0 blockiert, 0 nicht ausgefuehrt; 1025,83 s

Der erste Supertest scheiterte ausschliesslich am veralteten QA-001-Funktionsinventar. Das Inventar wurde mit dem vorgesehenen Generator erneuert; der anschliessende Volltest ist gruen. Ein nicht angefragter Supertest gilt projektweit als erledigt und ist kein Abschlussblocker.

## Aktiver Punkt: TD-0077 / JA-049

`JA-049 Stellenboerse als stabilen HTML-Einstieg atomar publizieren` ist der naechste fachliche Punkt. Reihenfolge danach: `JA-049 -> JA-054 -> JA-056 -> JA-050`.

Ziel und Grenzen:

- Einen kanonischen lokalen HTML-Einstieg unter `html/jobagent/index.html` bzw. `http://127.0.0.1:8500/html/jobagent/` mit Standardansicht Stellen schaffen.
- Stellen-, Firmen-, Quellenstatus- und Zaehlerdaten muessen aus exakt einer persistierten Storegeneration stammen. Rendern und validieren in temporaerer Ausgabe, erst danach ueber den vorhandenen atomaren Writer publizieren.
- `company-coverage.html` und zeitgestempelte Daily-Reports bleiben als Diagnose-/Archivpfade erreichbar. Fehler duerfen die letzte gueltige Publikation nicht ersetzen; Browserlokale persoenliche Daten bleiben unveraendert.
- Firmen ohne offene Stellen bleiben auffindbar. Vollstaendiger Leerscan bedeutet ehrlich „0 offene Stellen erfasst“; partielle oder fehlerhafte Quellen heissen nicht unbelegt Null.
- Keine neue API, kein Clouddeployment, keine manuelle Produktdatei-Ersetzung, kein Status-/Exitcodebruch und kein pauschales CI-Repinning.

Empfohlener Start:

1. Bestehende Start-/Reportlinks, DailyRun-/Operations-/Report-/Coverage-Publikationspfade und atomaren Writer inventarisieren; keine Annahme ueber bereits vorhandenes `index.html` treffen.
2. Eine feste Publikations- und Generationsschnittstelle mit isolierter Erfolgs-, Leerscan-, PARTIAL-, Fehler-zwischen-Rendern-und-Austausch- und Wiederholungslauffixture definieren.
3. Einstieg und Navigation implementieren, anschliessend nur passende DailyRun-/Operations-/Report-/Coverage-Funktionstests ausfuehren. Erst nach komplettem JA-049 den Supertest ausfuehren; falls nicht angefragt, als erledigt behandeln.
4. Bei Abschluss Evidence erzeugen, `Roadmap.md` aktiv bereinigen, den abgeschlossenen Block vollstaendig nach `Roadmap_archive.md` rotieren, Todo auf den naechsten Anker setzen und `./ci.cmd stp` ausfuehren.

## Betriebs- und Sicherheitslage

- Devserver ausschliesslich mit `./ci.cmd devserver-status` oder `./ci.cmd devserver-start` auf Port 8500 betreiben; keine zweite Instanz starten. Beim letzten Check lief ein vorhandener Listener auf 8500.
- SonarQube nur ueber `./ci.cmd sonar`. `route_ok=false` betrifft ausschliesslich gebuendelte Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/...` (Steuerzeichen/offene Fence) und bleibt `TD-0085`; diese Dateien nicht im Rahmen von JA-049 aendern.
- Browseraudits sehen Kaspersky-Injektionsanfragen als Umgebungsrauschen. Sie sind kein Produktnetzwerkzugriff, sofern der gezielte Test sie explizit ausfiltert.
- README ist nicht zu aendern. Nur funktionsbezogene Tests waehrend der Umsetzung; Supertest erst nach Abschluss des jeweiligen Roadmap-Punkts.
