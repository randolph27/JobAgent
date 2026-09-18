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

`JA-055 Unpassende Stellen und Arbeitgeber reversibel aus der persoenlichen Anzeige ausblenden` ist begonnen, aber nicht abnahmebereit. Die Roadmap bleibt unveraendert aktiv; keine Rotation. Fachliche Reihenfolge danach: `JA-049 -> JA-054 -> JA-056 -> JA-050`.

### Bereits umgesetzt

- `html/jobagent/assets/jobboard-state.js`: v2-Zustand besitzt additive optionale Bereiche `hidden_jobs` und `hidden_companies`. Eintrag: `hidden`, Grund (`ROLE`, `LOCATION`, `CONDITIONS`, `EMPLOYER`, `OTHER` oder leer), Text mit maximal 500 Unicode-Codepoints und UTC-`updated_at`.
- Neue APIs `setVisibility(storage, scope, id, hidden, options, now)` und `visibilityFor(state, jobId, companyId)`. Job-Ausblendung hat Vorrang; die Wiederherstellung eines Jobs hebt eine wirksame Firmenausblendung nicht auf. Der Import vereinigt Ausblendungen je stabiler ID nach neuerem Zeitstempel; bei Gleichstand bleibt der lokale Wert erhalten.
- `schemas/jobagent.user-state.schema.json`: additive Schemafelder und Validierung fuer beide Bereiche. Alte v1- und bestehende v2-Zustaende ohne Bereiche migrieren weiterhin zu leeren Bereichen.
- `src/JobAgent.Report.psm1`: Stellenansicht bietet Sichtbarkeit `visible`, `all` und `hidden`; Karten haben die Jobaktion „Nicht interessant“/„Stelle wieder einblenden“, Firmen die Aktion zum Ausblenden/Wiederherstellen. In Standardansicht bleiben lokal markierte Favoriten/Bewerbungen trotz Ausblendung sichtbar und erhalten ein Text-Badge.
- `tests/fixtures/jobagent/hidden-jobs.json`, `tests/Test-JobAgentUserState.ps1` und `tests/Test-JobAgentReport.ps1` decken ID-Trennung, Vorrang, Wiederherstellung, Textgrenze, Import gegen Wiederbelebung aelterer Werte, Schema und gerenderte Bedienelemente ab.
- `importState` persistiert jetzt auch einen Import, der ausschliesslich geaenderte Ausblendungen enthaelt. Zuvor wurde dieser Fall wegen einer Pruefung nur auf `changed_job_ids` nicht geschrieben.
- Die Ausblendungsbedienung ergaenzt Grundauswahl, maximal 500 Codepoints Erlaeuterung, global erreichbares „Rueckgaengig“ und einen Firmenhinweis mit Anzahl erfasster/offen ausgeblendeter Stellen. Ausblendgruende bleiben im Local Storage; sie werden nicht in URL oder Reportdaten geschrieben.
- `tests/Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` ist als gezielter Browserfall angelegt. Er prueft Grund/Text, Rueckgaengig, Firmenvorrang, einzelne Wiederherstellung, Reset und externe Netzwerkanfragen. Der Lauf hat im Tool-Runner jedoch nicht innerhalb der Laufzeit abgeschlossen; es liegt kein gruener Browsernachweis vor.

### Verifiziert

- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` -> Exit `0`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` -> Exit `0`.
- `./ci.cmd devserver-status` -> Exit `0`, vorhandener CI-verwalteter Devserver auf Port 8500.
- Kein Supertest ausgefuehrt; laut Nutzerauftrag ist das kein Abschlussblocker.

### Konkreter Fortsetzungsschnitt

1. Den Browserfall `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1 -VisibilityOnly` diagnostizieren. Der letzte Lauf blieb im Playwright-Abschnitt haengen und wurde beendet; zuerst erzeugte `logs/jobagent/QA-004/qa004-*` und Browserkonsolen read-only auswerten. Keine unbestaetigte Gruenmeldung daraus ableiten.
2. Sichtbarkeitsresolver vervollstaendigen: fuer Job/Firma/Job+Firma/keine Ausblendung in `visible`, `all`, `hidden` exakte Distinct-IDs, lokale Favoriten/Bewerbungen, Reset, Reload, Speicherfehler, Import und neue Stelle derselben ausgeblendeten Firma nachweisen. Gleiche Namen mit unterschiedlichen IDs muessen getrennt bleiben.
3. Die Kopfzeile des gemeinsamen Filterresolvers um exakte Werte „X sichtbare Treffer, Y durch Ausblendung ausgeschlossen“ erweitern. Y darf einen Job mit eigener und Firmenausblendung nur einmal zählen und muss weitere Filter bereits berücksichtigen.
4. Nach gruenem fokussiertem Browserfall die vier Viewports 1920/1366/800/390 pruefen, Evidence, Matrix und Funktionsinventar aktualisieren. Erst bei belegter Erfuellung Roadmap/Todo rotieren; sonst `TD-0082` offen lassen.

## Betriebsregeln und bekannte Restlage

- Devserver ausschliesslich mit `./ci.cmd devserver-status` beziehungsweise `./ci.cmd devserver-start` auf Port 8500 betreiben; keine zweite Instanz erzeugen.
- SonarQube nur mit `./ci.cmd sonar` verwenden. `route_ok=false` betrifft ausschliesslich vorhandene Steuerzeichen bzw. eine offene Code-Fence in gebuendelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/...`; dies ist als separates `TD-0085` offen und kein JA-055-Blocker. Die JRE-Dateien nicht im Rahmen von Produktpunkten aendern.
- Fuer laufende Roadmap-Arbeit nur passende Funktionstests verwenden. Nach komplettem Punkt ist Supertest erlaubt; ein nicht angefragter Supertest blockiert weder Abschluss noch Roadmap-Rotation.
- Die im Commit enthaltenen Aenderungen `html/jobagent/ja-022-viewport-audit.html` und `output/playwright/ja-022-fixture-viewport-*.png` gehoeren zu einer bereits vorhandenen Viewport-Aktualisierung und wurden auf ausdrueckliche Anweisung mit dem bereinigten Worktree uebernommen.
