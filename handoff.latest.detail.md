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

## Naechster Punkt: TD-0082 / JA-055

Als naechstes `JA-055 Unpassende Stellen und Arbeitgeber reversibel aus der persoenlichen Anzeige ausblenden` nach `Roadmap.md` umsetzen. Fachliche Reihenfolge: `JA-055 -> JA-049 -> JA-054 -> JA-056 -> JA-050`.

1. Den browserlokalen v2-Zustand mit `hidden_jobs` und `hidden_companies` auf stabilen IDs spezifizieren; Grund, optionalen Text, UTC-Aenderungszeit, Import-/Exportkonflikte und v1-Kompatibilitaet abdecken.
2. Job- und Firmenausblendung mit eindeutigem Vorrang implementieren: effektiv verborgen bei Job **oder** Firma; eine Job-Wiederherstellung hebt die Firmenausblendung nicht auf. Keine Loeschung von Crawl-, Firmen-, Favoriten-, Bewerbungs- oder Termindaten.
3. Sichtbarkeitsmodi `visible`, `all`, `hidden`, genaue sichtbare/ausgeschlossene Distinct-Job-Zaehler sowie Verwaltungs-/Wiederherstellungsansicht in den bestehenden gemeinsamen Filterresolver integrieren. Filterreset darf keine gespeicherte Ausblendung loeschen.
4. Fixture- und Funktionsfälle fuer gleiche Namen mit verschiedenen IDs, gleiche Firma/mehrere Jobs, alle Job-/Firmenkombinationen, ausgeblendete Favoriten/Bewerbungen, Reload, Export/Import, Quota-Fehler und neue Stellen einer ausgeblendeten Firma erstellen.
5. Erst nach fachlichem Abschluss Browseraudit bei 1920/1366/800/390 CSS-Pixeln ausfuehren, Matrix/Inventar aktualisieren und den Punkt rotieren. Ein nicht angefragter Supertest gilt als erledigt; bei Ausfuehrung zuerst den konkreten Funktionsfall isolieren.

## Betriebsregeln und bekannte Restlage

- Devserver ausschliesslich mit `./ci.cmd devserver-status` beziehungsweise `./ci.cmd devserver-start` auf Port 8500 betreiben; keine zweite Instanz erzeugen.
- SonarQube nur mit `./ci.cmd sonar` verwenden. `route_ok=false` betrifft ausschliesslich vorhandene Steuerzeichen bzw. eine offene Code-Fence in gebuendelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/...`; dies ist als separates `TD-0085` offen und kein JA-055-Blocker. Die JRE-Dateien nicht im Rahmen von Produktpunkten aendern.
- Fuer laufende Roadmap-Arbeit nur passende Funktionstests verwenden. Nach komplettem Punkt ist Supertest erlaubt; ein nicht angefragter Supertest blockiert weder Abschluss noch Roadmap-Rotation.
- Die im Commit enthaltenen Aenderungen `html/jobagent/ja-022-viewport-audit.html` und `output/playwright/ja-022-fixture-viewport-*.png` gehoeren zu einer bereits vorhandenen Viewport-Aktualisierung und wurden auf ausdrueckliche Anweisung mit dem bereinigten Worktree uebernommen.
