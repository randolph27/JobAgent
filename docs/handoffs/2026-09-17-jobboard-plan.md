# Uebergabe: Stellenboersen-Planung

Stand: 2026-09-17. Ausschliesslich Roadmap und erforderliche Planungs-/Todo-/Checkpoint-/Handoffdateien bearbeiten; nach STP, bereinigtem Worktree, Stage/Commit/Push stoppen. Keine Implementierung in diesem Auftrag.

## Ergebnis und Reihenfolge

Acht neue offene Punkte JA-043 bis JA-050, jeweils Beschreibung mit exakt drei checkboxbaren Teilbildern, Scope/No-Gos, beobachteter Ist-Stand, Screenshotbindung, Abhaengigkeiten, Aufwand/Dauer, ordinaler Prioritaetsscore, Begruendung, Risiken, Meilenstein/Parallelisierbarkeit, drei Umsetzungsschritte, Evidence, konkrete Funktionstests, Audit und Abschluss-Supertest.

M1 definiert Stellenidentitaet/Verfuegbarkeit, verbindet wachsenden Firmenkern mit konkreten Stellen und schuetzt persoenliche Markierungen. M2 liefert Trefferseite, deterministische Filter und Detailansicht mit zwei unabhaengigen Sternen. M3 integriert stabilen lokalen Einstieg und prueft gesamten Wachstum-/Such-/Bewerbungsworkflow. Vorhandene Report-/Discovery-/Statuslogik wird erweitert, nicht als fehlend neu geplant.

Annahmen: 1 Entwickler, 0,7 FTE, lokaler Einzelbenutzer; 17–27 PT und 27–43 Arbeitstage aus Einzelkorridoren. Termin, Teamkapazitaet und reale Stellenzahl nicht bestaetigt. Gebiets- und Berufsneutralitaetsvertrag bleibt erhalten. BrowserlocalStorage ist der minimale Planungsdefault; kein Cloud-/Geraetesync, keine automatische Bewerbung.

## Ausgangsbestand und Sicherung

Bei Beginn waren nur `data/jobagent/company-candidate-verification.queue.json` und `html/jobagent/company-coverage.html` bereits geaendert. Diese gehoeren nicht in den Planungscommit. Bytegleiche Kopien samt SHA256-Manifest liegen lokal unter `backups/roadmap-jobboard-20260917/`; die Baseline benennt Originalpfade und Hashes. Die gezielte Git-Stash-Sicherung wird im Validierungsnachweis ueber ihren unveraenderlichen Commit-Hash erfasst; keine pauschale Loeschung, kein Hard Reset, kein Aufnehmen fremder Produktivaenderungen.

Das Nutzerbild ist nur im Chat verfuegbar, nicht als lokale Originaldatei. Das versionierte Referenzmanifest beschreibt diese Grenze und bindet das vorhandene historische Bild getrennt ein; es wird kein neu gebautes Bild als Original ausgegeben. Originaldatei bei spaeter verfuegbarem Zugriff unter dem dort genannten geplanten Pfad unveraendert sichern.

## Verifikation und Fortsetzung

Verbindlicher aktueller Ergebnisnachweis: `docs/reviews/2026-09-17-jobboard-plan-validation.json`. Er trennt Planstruktur, Todo-/Checkpoint-/Handoffparitaet, vorhandene fokussierte CI-Funktionstests und Git-Whitespacepruefung von kuenftiger Produktabnahme. Kein Supertest/Browserlauf/Livecrawl/Sonar im reinen Planungsschnitt.

Alle acht Produktpunkte bleiben `open`, keine Aufgabe wird als implementiert archiviert. Nach diesem Auftrag stoppen. Naechster Implementierungsanker fuer einen spaeteren Auftrag: JA-043, zuerst Ist-Feldmatrix/Status-/Quellenfrischevertrag aus vorhandenen Modulen und fixierter Fixture pruefen. Der generierte STP-Git-Snapshot beschreibt den Zustand VOR dem Abschlusscommit; eine Behauptung, dieser Snapshot enthalte seinen eigenen Commit-Hash, waere falsch.

## Bekannter Gesamtpruefbefund dieses Planungsschnitts

`./ci.cmd verify` war erfolgreich und fuehrte ausschliesslich `Test-JobAgentCiContracts.ps1` aus. `./ci.cmd route-check` endete mit Exit 1: zehn Formfeed-Steuerzeichen in zwei mitgelieferten `freetype.md`-Lizenzdateien und eine offene Markdown-Fence in `giflib.md`, jeweils unter dem ignorierten lokalen `.ci/tools/sonar/`-Werkzeugbestand. Keine dieser Dateien wurde in diesem Auftrag geaendert. Die globale Routepruefung bleibt deshalb rot; sie wird nicht durch Toolchainmutation, geaenderte Ausschlussregeln oder einen vorgetaeuschten Erfolg bereinigt. Der Planungsdiff wird getrennt auf Markdown/Whitespace/Schema/Zustandsparitaet geprueft. Dieser Befund erfordert keinen Produktcode im ausdruecklich auf Planung begrenzten Auftrag.

`./ci.cmd self-check` meldet zusaetzlich genau einen Befund `immutable_modified: .ci/ci.config.json`. Die Konfiguration ist im Git-Blobvergleich identisch zu HEAD und wurde in diesem Planungsschnitt nicht editiert; der vorhandene Immutable-Pin passt nicht zum Dateihash. Kein Repinning oder Konfigurationsfix innerhalb dieses Planungsauftrags. Todo-/Handoff-Invarianten erzeugten keinen Self-Check-Befund. Exakter Hashvergleich und beide globalen Fehlschlaege stehen im Validierungsnachweis.

Wiederherstellung der ausgeklammerten Ausgangsaenderungen bei Bedarf: `git stash apply b75275258acdf5c883c59fc73c396da4a0012596` (wuerde den Worktree wieder aendern; in diesem Auftrag bewusst nicht ausgefuehrt). Bytegenaue Sicherung mit Originalzeilenenden bleibt unter dem genannten Backuppfad.
