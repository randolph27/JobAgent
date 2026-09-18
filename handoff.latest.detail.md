# Uebergabe-Details

Stand: 2026-09-18. Der zugehoerige maschinelle Zustand steht in `handoff.latest.json`; der aktive Todo-Punkt ist `TD-0082`.

## Abgeschlossen: JA-053

`JA-053 Fachliche Aenderungen einer Stelle als belegte Chronik anzeigen` ist abgeschlossen und vollstaendig nach `Roadmap_archive.md` rotiert. `TD-0081` ist aus dem aktiven Todo entfernt und im Master-Index als erledigt registriert.

- Die Change-Projektion ordnet Events ausschliesslich stabilen `job_id` zu und rendert sichere Vorher/Nachher-Klartexte.
- Die Fixture `tests/fixtures/jobagent/job-change-history.json` sowie `tests/Test-JobAgentChangeHistoryBrowserAudit.ps1` belegen Leerzustand, 20 von 21 anfangs sichtbare Ereignisse, Aufklappen des Rests, Tastaturbedienung, fehlende Altsnapshots, keinen Roh-HTML-Eintrag und die Viewports 1920/1366/800/390 CSS-Pixel.
- Der Browsernachweis liegt unter `logs/jobagent/JA-053/change-cases.json`; der kanonische Screenshot ist `doc/roadmap-screenshots/JA-053-change-detail-1366.png` (SHA-256 `f98b88268f9fb0537f8ff560abe3596b11eb04aa879a862828a618abb041f011`).
- `docs/reviews/JA-053-acceptance.md`, `docs/test-matrix.json`, `docs/test-matrix.md` und das Funktionsinventar sind aktualisiert.
- Ein zuerst erkannter Fehler in `Test-JobAgentDailyRun.ps1` war ausschliesslich eine fehlende Normalisierung dynamischer `change:`-Event-IDs in Reporthashes. Die Regex deckt dieses Praefix nun ab; der fokussierte Test ist gruen.
- `./ci.cmd supertest` endete danach gruen mit 32/32 bestanden, 0 fehlgeschlagen, 0 blockiert, 0 nicht ausgefuehrt. `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` ist ebenfalls gruen.

## Laufender Punkt: TD-0082 / JA-055

### Aktualisierung 2026-09-18 15:10+02:00

- Ausführlicher Einstieg für den nächsten Chat: `docs/handoffs/2026-09-18-ja055-continuation.md`.
- Die Sichtbarkeitsverwaltung wird jetzt zusätzlich an 390×844, 800×1024, 1366×768 und 1920×1080 funktional auditiert. Der isolierte Browserlauf prüft horizontalen Overflow, Überlappungen, mindestens 44 CSS-Pixel hohe Controls und abgeschnittenen Text in der Verwaltungsansicht.
- Neu erzeugte Evidence: `logs/jobagent/JA-055/visibility-cases.json`, `doc/roadmap-screenshots/JA-055-hidden-management-390.png` und `docs/reviews/JA-055-acceptance.md`. Der Browserfall belegt 262 sichtbare sowie 2 ausgeschlossene Stellen, Grund/Text, Rückgängig, Arbeitgebervorrang, lokalen Reset und keine fachlichen Bediennetzwerkzugriffe.
- Grün: `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly`.
- Offen bleibt allein der geforderte bestehende Daily-Run-Funktionstest: `Test-JobAgentDailyRun.ps1` beendet sich im Akquisepfad nicht innerhalb des beobachteten Zeitfensters. Der letzte Trace befand sich in der Kandidatenaufbereitung; daraus wurde keine fachliche Aussage abgeleitet. JA-055 bleibt offen. Ein nicht angefragter Supertest gilt als erledigt und ist kein Restpunkt.

### Aktualisierung 2026-09-18 14:49+02:00

- Aktiver Punkt bleibt `TD-0082` / `JA-055`; keine Roadmap-Rotation. Die Kernfunktion ist umgesetzt, die vollständige Abnahme und die geforderten Evidence-Artefakte fehlen noch.
- `src/JobAgent.Report.psm1` ergänzt die Sichtbarkeitsverwaltung: Im Modus `visibility=hidden` erscheint eine explizite Liste aller lokalen Job- und Firmenausblendungen mit Grund, optionalem Text und Wiederherstellung. Auch nicht mehr im aktuellen Report vorhandene IDs bleiben dort wiederherstellbar.
- Die Trefferkopfzeile weist die zur aktuellen Filtermenge passenden Werte als „X sichtbare Treffer, Y durch Ausblendung ausgeschlossen“ aus. Eine ausgeblendete Stelle mit zusätzlicher Firmenausblendung zählt genau einmal. Favoriten und Bewerbungen bleiben trotz Ausblendung sichtbar und werden nicht als ausgeschlossen gezählt.
- `tests/Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` ist grün. Der Test belegt Grund/Text, sofortiges Rückgängig, Firmenvorrang, erneutes Einblenden einer einzelnen Stelle bei weiterhin ausgeblendetem Arbeitgeber, Reset des Sichtbarkeitsfilters, Verwaltungsansicht und den Zählerfall `262` sichtbar / `2` ausgeschlossen. Die externen Kaspersky-Web-Anti-Virus-Injektionen werden als Umgebungsrauschen ausgefiltert; fachliche Browsernetzwerkzugriffe treten nicht auf.
- Grün: `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`; `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` lieferte innerhalb von rund vier Minuten keine Ausgabe und wurde mit Strg+C beendet. Kein Ergebnis daraus ableiten; als nächstes gezielt dessen Hänger analysieren, bevor JA-055 abgeschlossen wird.
- Nicht erstellt bzw. nicht verifiziert: `docs/reviews/JA-055-acceptance.md`, `logs/jobagent/JA-055/visibility-cases.json`, `doc/roadmap-screenshots/JA-055-hidden-management-390.png`, vollständiger Browseraudit mit 1920/1366/800/390 und Aktualisierung von Testmatrix/Funktionsinventar.
- Kein Supertest ausgeführt. Gemäß aktuellem Nutzerauftrag ist ein nicht angefragter Supertest kein Abschlussblocker.

`JA-055 Unpassende Stellen und Arbeitgeber reversibel aus der persoenlichen Anzeige ausblenden` ist begonnen, aber nicht abnahmebereit. Die Roadmap bleibt unveraendert aktiv; keine Rotation. Fachliche Reihenfolge danach: `JA-049 -> JA-054 -> JA-056 -> JA-050`.

### Bereits umgesetzt

- `html/jobagent/assets/jobboard-state.js`: v2-Zustand besitzt additive optionale Bereiche `hidden_jobs` und `hidden_companies`. Eintrag: `hidden`, Grund (`ROLE`, `LOCATION`, `CONDITIONS`, `EMPLOYER`, `OTHER` oder leer), Text mit maximal 500 Unicode-Codepoints und UTC-`updated_at`.
- Neue APIs `setVisibility(storage, scope, id, hidden, options, now)` und `visibilityFor(state, jobId, companyId)`. Job-Ausblendung hat Vorrang; die Wiederherstellung eines Jobs hebt eine wirksame Firmenausblendung nicht auf. Der Import vereinigt Ausblendungen je stabiler ID nach neuerem Zeitstempel; bei Gleichstand bleibt der lokale Wert erhalten.
- `schemas/jobagent.user-state.schema.json`: additive Schemafelder und Validierung fuer beide Bereiche. Alte v1- und bestehende v2-Zustaende ohne Bereiche migrieren weiterhin zu leeren Bereichen.
- `src/JobAgent.Report.psm1`: Stellenansicht bietet Sichtbarkeit `visible`, `all` und `hidden`; Karten haben die Jobaktion „Nicht interessant“/„Stelle wieder einblenden“, Firmen die Aktion zum Ausblenden/Wiederherstellen. In Standardansicht bleiben lokal markierte Favoriten/Bewerbungen trotz Ausblendung sichtbar und erhalten ein Text-Badge.
- `tests/fixtures/jobagent/hidden-jobs.json`, `tests/Test-JobAgentUserState.ps1` und `tests/Test-JobAgentReport.ps1` decken ID-Trennung, Vorrang, Wiederherstellung, Textgrenze, Import gegen Wiederbelebung aelterer Werte, Schema und gerenderte Bedienelemente ab.
- `importState` persistiert jetzt auch einen Import, der ausschliesslich geaenderte Ausblendungen enthaelt. Zuvor wurde dieser Fall wegen einer Pruefung nur auf `changed_job_ids` nicht geschrieben.
- Die Ausblendungsbedienung ergaenzt Grundauswahl, maximal 500 Codepoints Erlaeuterung, global erreichbares „Rueckgaengig“ und einen Firmenhinweis mit Anzahl erfasster/offen ausgeblendeter Stellen. Ausblendgruende bleiben im Local Storage; sie werden nicht in URL oder Reportdaten geschrieben.
- `tests/Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` ist als gezielter Browserfall angelegt. Er prueft Grund/Text, Rueckgaengig, Firmenvorrang, einzelne Wiederherstellung, Reset, externe Netzwerkanfragen und die vier Pflichtviewports; der aktuelle Lauf ist gruen.

### Verifiziert

- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` -> Exit `0`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` -> Exit `0`.
- `./ci.cmd devserver-status` -> Exit `0`, vorhandener CI-verwalteter Devserver auf Port 8500.
- Kein Supertest ausgefuehrt; laut Nutzerauftrag ist das kein Abschlussblocker.

### Konkreter Fortsetzungsschnitt

1. Den bestehenden Akquisepfad von `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` isolieren. Der Lauf blieb bei der Kandidatenaufbereitung CPU-gebunden; den konkreten Teiltest mit begrenzter Fixture reproduzieren, bevor ein Produkt- oder Testfix erfolgt.
2. Danach die noch offenen JA-055-Fälle für alle Sichtbarkeitsmodi als feste Wahrheitstabelle nachziehen: Job/Firma/Job+Firma/keine Ausblendung, lokale Favoriten/Bewerbungen, Reload, Speicherfehler, Import und neue Stelle derselben Firma. Gleiche Namen mit unterschiedlichen IDs bleiben getrennt.
3. Testmatrix und Funktionsinventar erst nach einem vollständigen, reproduzierbar grünen Daily-Run ergänzen. Erst dann Roadmap/Todo rotieren und den Supertest ausführen.

## Betriebsregeln und bekannte Restlage

- Devserver ausschliesslich mit `./ci.cmd devserver-status` beziehungsweise `./ci.cmd devserver-start` auf Port 8500 betreiben; keine zweite Instanz erzeugen.
- SonarQube nur mit `./ci.cmd sonar` verwenden. `route_ok=false` betrifft ausschliesslich vorhandene Steuerzeichen bzw. eine offene Code-Fence in gebuendelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/...`; dies ist als separates `TD-0085` offen und kein JA-055-Blocker. Die JRE-Dateien nicht im Rahmen von Produktpunkten aendern.
- Fuer laufende Roadmap-Arbeit nur passende Funktionstests verwenden. Nach komplettem Punkt ist Supertest erlaubt; ein nicht angefragter Supertest blockiert weder Abschluss noch Roadmap-Rotation.
- Die im Commit enthaltenen Aenderungen `html/jobagent/ja-022-viewport-audit.html` und `output/playwright/ja-022-fixture-viewport-*.png` gehoeren zu einer bereits vorhandenen Viewport-Aktualisierung und wurden auf ausdrueckliche Anweisung mit dem bereinigten Worktree uebernommen.
