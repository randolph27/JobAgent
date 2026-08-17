# Universeller Projekt- und CI-Arbeitsvertrag

Diese README ist der vollstaendige, additive Arbeitsvertrag fuer Projekte, die mit dem Workflow-Bootstrap verwaltet werden. Sie ersetzt keinen bewaehrten Inhalt durch einen kleineren gemeinsamen Nenner. Gemeinsame Regeln gelten immer; projektbezogene Regeln gelten zusaetzlich, sobald das zugehoerige Profil ausgewaehlt wurde.

Ausfuehrbarer Code gehoert in `ci.cmd`, `.ci/bin/ci.ps1` und `.ci/bin/**/*.ps1`. Die README beschreibt Zweck, Reihenfolge, Grenzen, Nachweise und Bedienung. Shell-Snippets in der README sind Bedienbeispiele oder Notfallprozeduren, aber keine versteckte Ersatzimplementierung fuer fehlende CI-Funktionen.

## 1. Bindungs- und Vorrangregeln

Die Regeln werden in dieser Reihenfolge ausgewertet:

1. ausdrueckliche aktuelle Nutzeranweisung;
2. Sicherheits-, Datenschutz- und Destruktionsgrenzen;
3. dieser universelle Vertrag;
4. genau ein ausgewaehlter vollstaendiger Profilvertrag;
5. projektspezifische `README.md`, `AGENTS.md`, Konfiguration und Roadmap;
6. generierte Kataloge und rein beschreibende Historien.

Widersprechen sich zwei Profilvertraege, werden sie nicht vermischt. Fuer ein Projekt gilt genau das Profil, das in `.ci/ci.config.json` beziehungsweise der zentralen Projektbindung festgelegt ist. Ein neues Projekt startet mit dem fachlich naechsten Profil und dokumentiert jede Abweichung additiv. Bestehende Funktionen, Commands, Nachweisfelder und Recovery-Wege werden nicht still entfernt.

## 2. Projektparameter

Vor der ersten schreibenden Operation muessen mindestens diese Werte feststehen:

| Parameter | Bedeutung | Ablage |
|---|---|---|
| `project_name` | stabiler Anzeigename | README und CI-Konfiguration |
| `project_root` | kanonischer absoluter Projektpfad | zentrale Bindung, nicht hart in Modulen |
| `project_kind` | Web/Node, Kotlin/Multiplatform, Android oder erweiterter Typ | Profil und Konfiguration |
| `build_system` | zum Beispiel npm, Gradle oder mehrere Lanes | CI-Konfiguration |
| `dev_command` | fachlicher Startbefehl | CI-Konfiguration/Projektmodul |
| `verify_commands` | schnelle, vollstaendige und releasebezogene Gates | CI-Konfiguration/Profil |
| `dev_port` | reservierter Entwicklungsport oder `null` | CI-Konfiguration |
| `evidence_root` | versionierte oder lokale Nachweisablage | CI-Konfiguration |
| `roadmap_files` | aktive Roadmap, Index und Archive | CI-Konfiguration |
| `todo_files` | Eventlog, State, Master, Checkpoint und Handoff | CI-Konfiguration |
| `secret_sources` | erlaubte Umgebungsvariablen/Dateien, nie der Secretwert | lokale Konfiguration |

Unsichere Werte werden als offene Annahme oder Blocker dokumentiert. Pfade, Ports, Tasks, Modulnamen, SDK-Versionen, Geraete und externe Dienste werden nicht erfunden.

## 3. Verbindliche Dateiverantwortung

- `README.md`: vollstaendiger menschlicher Arbeits-, Agenten-, Test- und Betriebsvertrag.
- `ci.cmd`: duennes Windows-Einstiegsskript ohne fachliche Logik.
- `.ci/bin/ci.ps1`: Dispatcher, Integritaetspruefung, Modulimport und Exitcodevertrag.
- `.ci/bin/modules/*.ps1`: ausfuehrbare fachliche Commands; keine gekuerzten README-Ersatztexte.
- `.ci/ci.config.json`: projektspezifische Werte, keine Secrets.
- `Roadmap.md`: priorisierte, zukuenftige Arbeit und Akzeptanzvertrag.
- `Roadmap_archive.md` und Generationen: abgeschlossene oder ersetzte Punkte; Historie nicht umdeuten.
- `todo.events.jsonl`: append-only Ereignisse, soweit das aktive Schema dies vorsieht.
- `todo.state.json` und `todo.master.index.json`: maschinenlesbarer aktueller Zustand.
- `todo.checkpoint.json`: beweisbare Eventgrenze plus eingebetteter Wiederanlaufzustand.
- `handoff.latest.*`: letzter belegter Arbeitsstand, kein Ersatz fuer Roadmap oder Git.
- `.ci/run` und Laufzeitlogs: temporaer; keine Source of Truth und keine Secrets.

## 4. Verlustfreiheitsregel

Bei Konsolidierung, Portierung oder Verbesserung gilt:

1. Zuerst Inventar von Dateien, Funktionen, doppelten Definitionen, Commands, Parametern und Seiteneffekten erstellen.
2. Projektunterschiede als Profile oder Adapter erhalten, nicht durch einen kleinsten gemeinsamen Nenner ersetzen.
3. Doppelte Implementierungen nur entfernen, wenn Aufrufreihenfolge und Verhalten nachweislich aequivalent sind. Andernfalls bleiben sie erhalten.
4. Verbesserungen werden vor- oder nachgelagert, sofern eine Aenderung des Legacy-Bodys nicht zwingend ist.
5. Jede notwendige Transformation erhaelt Quellhash, Zielhash, Begruendung und Kompatibilitaetstest.
6. Kein Command, Recovery-Pfad, Diagnosefeld, Evidence-Artefakt oder Konfigurationsschluessel verschwindet ohne ausdrueckliche, dokumentierte Entscheidung.
7. README-Regeln werden nicht nur verlinkt oder zusammengefasst, wenn dadurch Bedingungen, Grenzwerte, Reihenfolgen oder No-Gos verloren gehen.

## 5. Standardablauf pro Arbeitseinheit

### 5.1 Orientierung

1. Nutzerauftrag, README, Profilvertrag und vorhandene `AGENTS.md` lesen.
2. Git-HEAD und bestehenden Arbeitsbaum read-only erfassen; fremde Aenderungen nicht ueberschreiben.
3. Roadmap, Todo-State, Checkpoint und Handoff auf denselben aktuellen Stand pruefen.
4. `ci.cmd self-check`, `ci.cmd env-inventory` oder die profilbezogene Diagnose ausfuehren, sofern dies fuer den Auftrag zulaessig ist.
5. Annahmen, Abhaengigkeiten, Risiken und den kleinsten vollstaendigen Arbeitsschnitt festlegen.

### 5.2 Umsetzung

1. Grundlagen und Abhaengigkeiten vor nachgelagerten Features bearbeiten.
2. Bestehende Schnittstellen, Datenformate, Commands und Exitcodes erhalten.
3. Mutable Nutzerdaten von verwalteter Runtime trennen.
4. Schreiboperationen atomar oder transaktional ausfuehren; bei Abbruch den Vorzustand restaurieren.
5. Long-running Prozesse ausschliesslich ueber die vorgesehenen Hintergrund-Commands starten.
6. Keine automatische Loeschung unerwarteter Dateien; melden, pruefen, dann gezielt entscheiden.

### 5.3 Validierung

Die Testtiefe richtet sich nach Risiko und Profil, nicht nach Dateizahl:

1. Parser, Format- und statische Contracts;
2. fokussierte Unit-/Modultests fuer den geaenderten Bereich;
3. Build-/Lint-/Route-/Integritaetspruefung;
4. Browser-, Viewport-, Emulator- oder Physical-Lane, wenn der geaenderte Bereich sie beruehrt;
5. Sonar/Security/Release-Gates nur gemaess Profilvertrag und Nutzerauftrag;
6. Nachweise mit Command, Exitcode, Zeitpunkt, Ziel, relevanter Version und Artefaktpfad.

Ein Test gilt nicht als gruen, wenn er nicht lief, nur Teilbereiche uebersprang oder eine Voraussetzung fehlte. Solche Faelle werden als `not-run`, `skipped` oder `blocked` mit Grund ausgewiesen.

### 5.4 Abschluss und Handoff

1. Diff und unerwartete Dateien pruefen.
2. Roadmap-Status nur bei belegter Akzeptanz aendern.
3. Todo, Checkpoint und Handoff konsistent aktualisieren.
4. Laufende Hintergrundprozesse gemaess Nutzerauftrag weiterlaufen lassen oder kontrolliert stoppen.
5. Ergebnis, Tests, verbleibende Risiken und naechsten konkreten Schritt nennen.
6. Git-Commit oder Push nur bei Auftrag beziehungsweise geltendem Profilvertrag; nie fremde Aenderungen einbeziehen.

## 6. CI-Commandvertrag

Der einzige regulaere Projekteinstieg ist:

```powershell
.\ci.cmd <command> [argumente]
```

Switch-artige Legacy-Argumente wie `-f`, `-Verbose` oder profilbezogene Optionen muessen unveraendert beim Zielcommand ankommen. Der Dispatcher darf sie nicht als eigene Parameter konsumieren.

Gemeinsame Commandgruppen, soweit im gewaehlten Profil vorhanden:

- Orientierung: `menu`, `self-check`, `doctor`, `env-inventory`, `preflight`;
- Arbeitszyklus: `start`, `tick`, `event`, `stp`, `critic`, `autopatch`, `patch-apply`;
- Todo/Handoff: `todo-seed`, `todo-rebuild`, `todo-compact`, `todo-prune`, `todo-rotate`, `todo-sanitize`;
- Integritaet: `drift-check`, `verify`, `route-check`, `bootstrap-verify`;
- Toolchain: `deps-bootstrap`, `gradle-bootstrap`, `gradle-autopsy`;
- Dienste: `devserver-start/status/stop`, `pyserver-start/status/stop`, `sonar-start/stop`;
- Qualitaet: `test-full`, `supertest`, `sonar`, `browser-smoke`, profilbezogene UI-/Viewport-/Geraetetests;
- Beobachtung: `observer-baseline`, `observer-check`, `observerd-start/status/stop`;
- Recovery: zentral `Audit`, `Repair` und `Update`; die historischen Namen `restore-immutables`, `repin-immutables` und `runtime-update` bleiben als sichere Kompatibilitaetsaufrufe erhalten. Ihre urspruengliche lokale Pin-/Snapshot-Semantik steht unveraendert im Referenzmodus bereit.

Der konkrete Profilvertrag bleibt fuer Commandnamen, Parameter, Reihenfolge, Seiteneffekte und Akzeptanz massgeblich.

## 7. Roadmap-Vertrag

Neue Punkte werden nicht in Eingabereihenfolge uebernommen. Reihenfolge: Abhaengigkeiten, kritischer Pfad, Risiko/Sicherheit, Wert pro Aufwand, Unsicherheit. Jeder Punkt enthaelt mindestens:

- eindeutige ID und Titel;
- messbare Beschreibung und Ist-Stand;
- Scope mit Dateien/Modulen und No-Gos;
- Abhaengigkeiten;
- Aufwand und Dauer mit benannten Kapazitaetsannahmen;
- Prioritaetsscore und kurze Ordnungsbegruendung;
- Risiken und Unsicherheiten;
- konkrete Schritte;
- Evidence;
- exakte Funktionstests;
- Audit-/Visual-/Device-Vertrag, sofern relevant;
- Meilenstein und Parallelisierbarkeit;
- Supertest-/Release-Gate gemaess Profil und Nutzerauftrag.

Screenshotgebundene Anforderungen behalten stabile Referenzpfade bis zur Archivierung. Archive werden nicht umgeschrieben, um einen spaeteren Zustand vorzutäuschen.

## 8. Todo-, Checkpoint- und Handoff-Vertrag

- Event-IDs sind eindeutig; Zeitstempel sind ISO 8601 mit Offset oder UTC.
- Das Eventlog hat dokumentierte Rotationsgrenzen fuer Alter, Zeilen und Bytes.
- Rotation erzeugt eine Generation mit Hash und atomarem Pointer; sie loescht keine unbelegte Historie.
- Der Checkpoint nennt die exakte letzte Event-ID oder Sequenz und enthaelt den dazugehoerigen Zustand.
- Hoechstens ein Eintrag ist `in-progress`, sofern das Schema nichts anderes festlegt.
- Roadmap-Abschluss, Todo-Status und Handoff duerfen sich nicht widersprechen.
- Bei unvollstaendiger Alt-Historie erfolgt zuerst ein read-only Audit; keine spekulative automatische Rekonstruktion.

## 9. Hintergrundprozesse

- Devserver, Watcher, Sonar und Observer niemals unbegrenzt im Vordergrund eines Tool-Runners starten.
- PID-/State-Datei, kanonisches CWD, Port, URL, Command und Startzeit erfassen.
- Vor Start vorhandenen Zustand pruefen; keine zweite Instanz blind starten.
- Logs append-only mit Groessenrotation; keine Secrets oder Tokens protokollieren.
- Stop zuerst ueber bekannte PID, danach kontrollierter Prozess-/Port-Fallback gemaess Profil.
- Fremde Prozesse auf demselben Port nicht ohne Identitaetspruefung beenden.

## 10. Sicherheit und Integritaet

- Secrets nur ueber erlaubte Environment-Variablen, lokale Secret-Dateien oder Secret Stores; nie in README, Config, Git-Diff, Logs oder Handoff.
- Downloads und Caches vor Nutzung kryptografisch pruefen; Hashfehler sind fail-closed.
- Pfade normalisieren und auf den erlaubten Root begrenzen; Reparse Points und Alternate Data Streams pruefen, wenn relevant.
- Verwaltete Runtime vor dem Start und nach dem Child-Prozess verifizieren.
- Manifesthashes schuetzen gegen Drift, nicht gegen einen Angreifer mit Schreibrecht auf Dateien und Manifest; ACL oder Signierung ist eine getrennte Authentizitaetsgrenze.
- Destruktive Schritte brauchen exakte Ziele, read-only Vorpruefung und eine wiederherstellbare Alternative.

## 11. Profilwahl

| Profil | Geeignet fuer | Additive Schwerpunkte |
|---|---|---|
| `ubuntu-web` | Node/Vite/Web/PWA und Quiz-/Content-Projekte | Browser-Review, Seed-Runner, Web-Release-Gates, Inhaltskataloge |
| `chess` | Kotlin-Multiplatform/Web mit umfangreicher Viewport-Pruefung | Viewport-Handshakes, Git-ACL-Diagnose, Test-Lane-Planung |
| `sound-profile` | native Android-Projekte | ADB, Emulator/Physical, Berechtigungen, Android-SDK und visuelle Device-Audits |

Fuer andere Projekte wird das naechste Profil kopiert und ausschliesslich additiv angepasst. Nicht passende produktspezifische Regeln werden explizit als `not-applicable` dokumentiert; sie werden nicht still geloescht.

## 12. Referenz- und Managed-Modus

Der Bootstrap stellt zwei bewusst getrennte Sichten bereit:

1. `templates/<profil>` enthaelt README, `ci.cmd`, Konfiguration und alle CI-Skripte bytegleich zum erfassten Quellstand. Dieser Modus ist der Verlustfreiheitsnachweis.
2. `profiles/<profil>` enthaelt die zentral verwaltete, gehaertete Laufzeit. Jede Abweichung ist katalogisiert und muss die Funktions-/Commandtopologie erhalten.

Neue Verbesserungen werden zuerst als zusaetzliche Pruefung, Wrapper oder Modul umgesetzt. Eine Aenderung des Legacy-Bodys ist nur zulaessig, wenn der Zweck nicht ausserhalb erreichbar ist und der Referenzbestand erhalten bleibt.

## 13. Read-only Orientierung und Installation

Read-only:

```powershell
D:\_Scripte\Bootstrap\bootstrap.cmd List
D:\_Scripte\Bootstrap\bootstrap.cmd Audit -CompareSources
D:\_Scripte\Bootstrap\bootstrap.cmd Plan -TargetRoot "<PROJEKTPFAD>" -Profile <profil>
```

`Install`, `Update`, `Repair` und das Kopieren eines Referenz-Templates sind schreibend und benoetigen einen ausdruecklichen Auftrag. Eine vorhandene `.ci/ci.config.json` bleibt ohne `-ReplaceConfig` erhalten.

## 14. Vollstaendige Profilvertraege

Die nachfolgenden Vertraege bleiben vollstaendig enthalten. Sie sind keine drei gleichzeitig geltenden Regelmengen: Es gilt der gemeinsame Vertrag plus genau der ausgewaehlte Profilvertrag. Beispiele mit festen Ports, Pfaden, Tasks, Screenshotordnern oder Produktthemen sind profilbezogen.
