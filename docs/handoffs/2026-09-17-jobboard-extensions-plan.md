# Uebergabe: sechs Ergaenzungen zur Stellenboersen-Roadmap

Stand: 2026-09-17. Nutzerauftrag ausschliesslich Planung, anschliessend STP, Worktree-Bereinigung, Stage/Commit/Push und Stopp. Kein Produktcode, keine neuen Testimplementierungen und keine Liveabrufe in diesem Auftrag.

## Konkretes Ergebnis

Sechs neue Punkte: JA-051 Zeitprojektion, JA-052 Bewerbungsorganisation, JA-053 Stellenchronik, JA-054 Abruf-/Terminkalender, JA-055 reversible Ausblendung, JA-056 gespeicherte Suchen/Sichtungsstand. Jeder enthaelt exakt drei detaillierte checkboxbare Beschreibungs-Unterpunkte und drei Umsetzungsschritte sowie alle README-Pflichtfelder, Abhaengigkeiten, Aufwand/Dauer, Prioritaetsscore, Risiken und Meilenstein/Parallelisierbarkeit.

Alle 14 offenen Punkte wurden nach Abhaengigkeiten geordnet: JA-043 -> JA-044 -> JA-051 -> JA-045 -> JA-046 -> JA-047 -> JA-048 -> JA-052 -> JA-053 -> JA-055 -> JA-049 -> JA-054 -> JA-056 -> JA-050. Bestehende acht Punkte bleiben erhalten, die Gesamtabnahme JA-050 umfasst jetzt auch die sechs Ergaenzungen. Ordinaler Score 100 minus 4 pro Rang, kein Messwert fuer wirtschaftlichen Nutzen.

Wichtige Vertragsanpassungen: JA-043 bleibt alleinige 7-Tage-Frischedefinition; JA-051 liefert gemeinsame Zeit-/Ereignisprojektion. JA-052 migriert den geplanten persoenlichen v1-Speicher nach v2 und bindet den Bewerbungsstern an die Bewerbungsstufe. JA-055/JA-056 ergaenzen optionale v2-Bereiche. Ausblendung vor gespeicherten Suchen, Kalender nach Daten-/Aufgabenprojektion und stabiler Publikation. Keine automatischen Bewerbungen, Nachrichten, externen Kalendersynchronisationen oder Scrapes durch Bedienaktionen.

Annahmen unveraendert: ein Entwickler, 0,7 FTE, 8 Stunden/PT, lokaler Einzelbenutzer. Zusaetzlicher Aufwand 8,5–15 PT / 14–24 Arbeitstage; gesamte Planung 25,5–42 PT / Summe gerundeter Einzelkorridore 41–67 Arbeitstage vor Parallelisierung. Teamkapazitaet und Zieltermin unbestaetigt. Keine Produktfunktion als erledigt markiert.

## Workflow und Pruefgrenzen

Bei Beginn war der Worktree sauber auf `b8e7b04ce25c335fe95316afe3de3faeda7867d8`. Acht alte Todo-IDs TD-0071 bis TD-0078 wurden erhalten und sechs neue IDs TD-0079 bis TD-0084 hinzugefuegt. Der bestehende Auto-Seeder wuerde bei nichtleerem State ueberspringen und im Force-Zweig nur neu hinzugefuegte Items zurueckschreiben; deshalb dokumentierte additive State-/Index-Synchronisation, kein Force-Seeding und keine Runtimeaenderung.

Aktueller Nachweis: `docs/reviews/2026-09-17-jobboard-extensions-plan-validation.json`. Dort Struktur, Abhaengigkeitsreihenfolge, Schaetzsummen, Quellenhashes, Todo-/Checkpoint-/Handoffparitaet und fokussierte Testresultate getrennt von globalen Gates ausweisen. Supertest, Browser-/Emulator-/Sonarlauf und Produktabnahme im Planungsschnitt nicht ausgefuehrt.

Bekannter Ausgangsbefund aus vorigem Auftrag: globale Routepruefung mit elf Markdown-Befunden in ignorierten Sonar-Werkzeug-Lizenzdateien; Self-Check mit unpassendem Immutable-Pin der gegen HEAD unveraenderten `.ci/ci.config.json`. Keine Toolchain-/Lizenz-/Pinreparatur in diesem Auftrag; aktuelle Wiederholungsresultate im Nachweis erfassen und nicht als gruen umdeuten. Original-Nutzerscreenshot weiterhin nur als Chatbild verfuegbar, historische Referenz/Manifest unveraendert erhalten.

Bestehender Sicherungs-Stash `b75275258acdf5c883c59fc73c396da4a0012596` und bytegenaue Sicherungen unter `backups/roadmap-jobboard-20260917/` gehoeren zum vorherigen Planungsschnitt und bleiben unveraendert; kein neuer Stash bei anfangs sauberem Worktree erforderlich. Wiederanwendung waere eine neue Aenderung des Worktrees und wird hier nicht ausgefuehrt.

## Stopgrenze und spaetere Fortsetzung

Nach geprueftem Planungscommit/Push stoppen. Keine Implementierung aus der allgemeinen Todo-Fortsetzungsregel ableiten. Bei spaeterem Implementierungsauftrag beginnt JA-043; alle 14 Punkte bleiben offen und `active_id` bleibt leer. Generierter STP-Git-Snapshot ist der Zustand vor Abschlusscommit; finalen Commit-/Pushstatus separat durch Git pruefen, keinen selbstreferenziellen Commit-Hash in den Handoff schreiben.

## Aktuelle ausgefuehrte Pruefungen

- Struktur-/Abhaengigkeits-/Schaetzpruefung: 14 Punkte, 42 Beschreibungs-Unterpunkte, keine vorwaerts gerichtete Pflichtabhaengigkeit, Schaetzsummen/0,7-FTE-Dauern konsistent.
- `./ci.cmd verify`: Exit 0, ausgefuehrt wurde der fokussierte `Test-JobAgentCiContracts.ps1` (14 Vertragsfaelle).
- `./ci.cmd route-check`: Exit 1, dieselben elf Befunde in unveraenderten Sonar-Lizenzdateien.
- `./ci.cmd stp`: Exit 0; anschliessend exakte letzte STP-Event-ID in State/Checkpoint synchronisiert.
- `./ci.cmd self-check`: Exit 1, einzig unveraenderter Config-Pin-Konflikt; keine gemeldete Todo-/Handoff-Invariantenverletzung.
- Finale Paritaets-/Whitespacepruefung und fokussierter Invariantentest werden im maschinenlesbaren Nachweis mit Ergebnis erfasst. Kein Supertest, keine neue Produktimplementierung.
