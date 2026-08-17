# PRISMA Wissensjaeger Quiz

PRISMA ist die Web/PWA-Referenz fuer das interaktive Wissenspanorama: Quizfragen, Auswertung, Wissens-Panorama und lokale Daten-/API-Vertraege werden zuerst fuer den Browser entwickelt.

## Produkt- und Dokumentationseinstieg

- Zielplattform Phase 1: Web/PWA, responsive und offline-faehig; Android bleibt in Phase 2 ein separater Wrapper ohne UI-Neuimplementierung.
- Lokales Setup: Abhaengigkeiten im Webverzeichnis installieren, Dev-Server ueber `cmd /c .\ci.cmd devserver-start` auf Port `8200` starten, Funktionstests gezielt mit `npx --no-install vitest run <testdatei> --maxWorkers=1 --no-file-parallelism` ausfuehren.
- Primaerdokumentation: [Produktprogramm](manual/PROGRAM.md), [Questions API Contract](manual/api/questions-contract.md), [Questions Graph Debug Contract](manual/api/questions-graph-debug-contract.md), [Architecture Contract](architecture.contract.md).
- Abschluss- und Release-Arbeit folgt dem untenstehenden CI- und Agentenvertrag; harte Regeln zu Plattform, Git, STP, Roadmap-Rotation und Testpflicht bleiben bindend.

## CI- und Agentenvertrag

PLATTFORMSTRATEGIE (hart)

Zielplattform Phase 1: WEB (PWA), responsive, offline-fähig, ohne native Abhängigkeiten.
Zielplattform Phase 2: ANDROID als Container/Wrapper der Web-App (z.B. WebView/Capacitor), ohne Re-Implementierung der UI.

No-Gos Phase 1:
- Keine Android-Module, kein Android-Gradle-Plugin, keine Jetpack-Compose/UI, keine Android-SDK-Abhängigkeiten im Core.
- Kein Code, der nur auf Android lauffähig ist (Import-Präfixe: android.*, androidx.*).
- Keine Architekturentscheidungen, die Web-Portierung erschweren (z.B. IO/Threads/Audio direkt platform-spezifisch im Core).

Muss Phase 1 liefern:
- Web-App als einzige referenzielle UI (Single Source of Truth).
- Klare Trennung: Core/Domain (plattformneutral) + Web-Adapter (Browser/JS APIs).
- Hybrid-Rendering: Nutzung von HTML5 Canvas für Performance-kritische Elemente (Eval-Bar, Heatmap) zur Vermeidung von DOM-Bloat.
- Design-Automatisierung: Integration von Canva via MCP zur automatisierten Erstellung von Social-Media-Assets und PGN-Cards.
- Gestalte die Benutzeroberfläche mit klaren, konsistenten Abständen, optischer Balance und einer intuitiven visuellen Hierarchie. Nutze Canva, um ein harmonisches Layout zu erstellen: Definiere zuerst ein responsives Raster, wähle eine reduzierte Farbpalette und setze konsistente Typografie ein. Strukturiere Navigation und Inhalte so, dass Nutzer mühelos durch die Seiten geführt werden. Vermeide visuelle Unruhe, hebe Call-to-Action-Elemente klar hervor und teste das Design mit Canva-Prototypen auf unterschiedlichen Geräten.

- CI-Verify: web build + web tests + lint; muss grün sein vor Merge/Commit.

Android Phase 2:
- Separate Schicht „android-wrapper“ (nur Shell/Container + Permissions + Packaging).
- Wrapper darf Core nicht verändern; nur hosten/konfigurieren.

- Die Plattform ist VScode. Nutze alle extensions, wenn sie hilfreich sind. Verwende PS um die installierten Plugins auszulesen. Versuche Chrome Debug und MCP zu nutzen.

		code --list-extensions --show-versions

	Als JSON:
	code --list-extensions --show-versions |
  ForEach-Object {
	$p = $_ -split '@', 2
	[pscustomobject]@{ extension = $p[0]; version = $p[1] }
  } | ConvertTo-Json -Depth 2 | Set-Content -Encoding UTF8 .\vscode-extensions.json





#########



Universal CI – Meisterprompt v3
Zweck
Kontinuierliche Entwicklung komplexer Software durch wechselnde Agents/Chats mit deterministischer Zustandsführung, minimalem manuellen Aufwand und konsistenten Artefakten.

1) Startparameter
workspace_root: <D:\_Scripte\Quiz>
mode: prod
agent_id: auto
preflight: strict
manual: auto
env_inventory: auto
deps_bootstrap: auto
browser_tests: staged|off
browser_test_interval: 15
verify_profile: standard|deep
verify_escalation: staged|off
observer: staged|off
observer_interval: 15
route_check: standard|strict|off

chat_flow_policy: autonomous|off
# autonomous: Keine Rückfragen/Bestätigungen/Smalltalk/Meta; fehlende Infos => blocked + reproduzierbare Steps + #ci stp.
sixth_rules: on|off
# on: .sixthrules/* ist bindend (maschinenlesbar für Sixth). README bleibt Source-of-Truth; Inhalte müssen konsistent sein.
terminal_profile: pwsh7|powershell5
terminal_reuse: off
terminal_output_limit: 500|2000
terminal_timeout_seconds: 600

## Dateischreibweise (Agent, hart)
- Normale Dateien (Roadmap/todo/manual/src/etc.) DIREKT schreiben (Terminal: Set-Content/Out-File). Keine IDE-/Chat-Patch-Mechanik.
- Read-only/Overwrite: vor Schreiben `attrib -R <datei>`.
- Das Patch-System wurde entfernt. Änderungen an CI-Runtime Dateien sind direkt erlaubt, sofern zuvor der Schreibschutz aufgehoben wurde.
- README.md: NO_TOUCH (nur auf expliziten User-Befehl ändern).

## Roadmap-Rotation (hart)
- Roadmap.md enthaelt nur aktive Punkte.
- Abgeschlossene Punkte werden nach Roadmap_archive.md verschoben (vollstaendig).
- Roadmap_index.md listet das Archiv und den Stichtag.
- Beim Chat-Start alle Roadmap-Dateien lesen (Roadmap.md + Roadmap_archive.md + Roadmap_index.md).

Defaults (wenn Zeile fehlt):
	• agent_id:auto (ableiten aus Host + kurzer Zufalls-ID; stabil pro Chat).
	• preflight:strict wenn mode:prod, sonst standard.
	• manual:auto, env_inventory:auto, deps_bootstrap:auto.
	• browser_tests:staged + browser_test_interval:15.
Minimal: workspace_root: <ABS_PATH>.
Validierung (Pflicht):
	• Pfad existiert und enthält README.md oder .git/.
	• Bei ungültigem Root: Arbeitsaufnahme blockieren; nur Root nachfordern.
manual-Regel:
	• Wenn manual: auto oder Zeile fehlt: suche im workspace_root nach manual/ oder manual.md und nutze es, falls vorhanden.
	• Wenn manual: none: Manual wird ignoriert.
	• Wenn Pfad angegeben: Datei/Ordner muss existieren; sonst ignorieren und in CAPSULE manual_missing:true setzen.
Manual-Ingest (token-sparend, deterministisch):
	• In manual/ nur Markdown-Dateien berücksichtigen; PDFs/Assets standardmäßig ignorieren.
	• Priorität: manual/summary.md → manual/index.md → manual.md → sonst erste *.md ≤ 200 KB.
	• manual.digest.json wird aus Dateimetadaten + Hash erzeugt (kein Volltext): path, size, mtime, sha256 (max 3 Dateien). Inhalt nur lesen, wenn Datei ≤ 80 KB und ein Policy-/No-Go-Abschnitt vermutet wird.
env_inventory-Regel:
	• Wenn env_inventory: auto oder Zeile fehlt: im workspace_root nach env-inventory.snapshot.md suchen und nutzen, falls vorhanden.
	• Wenn Pfad angegeben: Datei muss existieren; sonst ignorieren und in CAPSULE env_inventory_missing:true setzen.
	• Wenn env-inventory genutzt wird: env_inventory.digest.json erzeugen/aktualisieren (Single-Line-JSON, kurz) und danach nur bei Dateiänderung neu erstellen.


1.1) Sixth Rules (.sixthrules) (hart)
	• Zweck: Maschinenlesbare Regeln für Sixth/Agents (Projekt-Policy), um Chat-/Terminal-Flow konsistent zu halten.
	• Quelle: README.md bleibt Source-of-Truth; `.sixthrules/*` muss inhaltlich identisch bleiben (keine „abgespeckten“ Kopien).
	• Inhalt:
		○ `.sixthrules/01-ci-guardrails.md` (CI-Runtime Guardrails, hart)
		○ `.sixthrules/02-chat-flow.md` (Chat-Flow, hart)
	• Observer: `.sixthrules/*.md` zählt zu den Quellen für `sources_hash` (Drift sichtbar machen).

2) Quellenhierarchie
	1. toolchain.pins.md (falls vorhanden; Toolchain-Versionen, immutable)
	2. README.md (Regeln, CI-Contract; immutable)
	3. Roadmap.md (Plan; editierbar, aktive Punkte)
	4. Roadmap_archive.md (Historie, vollstaendig)
	5. Roadmap_index.md (Archiv-Uebersicht)
	6. architecture.contract.md (falls vorhanden; bindend)
3.1 browser-tests.contract.md (falls vorhanden; Browser-Test-Definition, bindend)
	7. manual/ oder manual.md (falls vorhanden; Vorgaben/Bedienung/Policies; immutable außer expliziter Änderung)
	8. env-inventory.snapshot.md (falls vorhanden; Umgebungsfakten: Tooling/Paths)
	9. handoff.latest.json (Resume-Anker)
	10. todo.events.jsonl (History, Truth)
	11. todo.state.json (aktueller Zustand, Truth)
	12. todo.current.md (View, kurz)
	13. Debug-/Sonst-Logs (Belege; keine Entscheidungsgrundlage)
Konfliktregel: höhere Priorität gewinnt.

3) Transaktionsmodell
Iteration = atomare Transaktion:
	1. Rehydrate
	2. Work (genau 1 Active Item)
	3. Verify (immer)
	4. Route-Check (immer; vor Commit)
	5. Git (immer)
	6. Meta-Flush (einmal)
Rehydrate (Start jeder Iteration):
	• Reihenfolge: README → Roadmap.md → Roadmap_archive.md → Roadmap_index.md → Contract → Manual (falls vorhanden) → env-inventory (falls vorhanden) → handoff → todo-state.
	• Gate: Wenn README/Roadmap-Dateien in dieser Session noch nicht gelesen wurden, müssen sie vor jedem anderen Read nachgeladen werden.
	• Manual dient Anforderungen/Policies/Bedienung; env-inventory dient ausschließlich der Tool-/Command-Auswahl.
Chat-Start (zusätzlich, genau einmal):
1. Preflight (siehe 7.1.1): nur read-only Checks + ggf. gradlew --stop.
	2. README.md lesen und cachen (Pflicht).
	3. Roadmap.md lesen und cachen (Pflicht).
	4. Roadmap_archive.md lesen und cachen (Pflicht).
	5. Roadmap_index.md lesen und cachen (Pflicht).
	6. architecture.contract.md lesen (falls vorhanden).
	7. Manual einmal ingestieren (falls vorhanden) und manual.digest.json erzeugen/aktualisieren (Single-Line-JSON, kurz; Metadaten+Hash, siehe 1).
	8. env-inventory einmal einlesen (falls vorhanden) and env_inventory.digest.json erzeugen/aktualisieren (Single-Line-JSON, kurz).
	9. Observer-Baseline sicherstellen (siehe 9):
		○ wenn observer: staged und observer.baseline.json fehlt: Baseline erzeugen.
		○ einmaliger observer-check ausführen.
	10. Aktion todo-compact durchführen, wenn Trigger erfüllt (siehe 5.5).
	11. Aktion todo-prune durchführen, wenn Pruning-Regel erfüllt ist (siehe 5.6).
	12. Aktion todo-rotate durchführen, wenn Rotation-Trigger erfüllt ist (siehe 5.6).
	13. todo.master.index.json einmal lesen (Überblick), danach nur bei Dateiänderung.
	14. todo.history.digest.json einmal lesen (Überblick über erledigte Tasks), danach nur bei Dateiänderung.
	15. Wenn browser_tests: staged: #ci browser-smoke prüfen/ausführen (siehe 7.1.3).
Gate:
	• Vor Schritt 1–5 dürfen keine anderen Dateien gelesen/geschrieben und keine Aktionen ausgeführt werden.
	• Ausnahme: Schritt 1 (Preflight) ist erlaubt und zählt nicht als Drift.
Regeln:
	• Während Work-Phase keine Meta-Dateien schreiben.
Progress-Regel (Anti-Loop):
	• Jede Iteration muss genau einen Fortschritt liefern: Code/Config-Änderung oder neue Evidence oder deterministischer Statuswechsel (blocked mit reproduzierbaren Schritten).
	• Wenn 2 Iterationen hintereinander kein Fortschritt (nur Wiederholung gleicher Reads/Commands/Antworten): sofort blocked + #ci stp.
	• Wiederholungen werden über fail_signature/last_cmd erkannt (siehe 6.5).
	• Bei >2 Iterationen ohne „grün“: splitten oder blocked mit reproduzierbaren Schritten.
	• Read-Caching: README/Roadmap-Dateien/Contract/Manual/env-inventory pro Iteration max. 1×; Re-Read nur bei Änderung oder Signal #ci stp (Legacy: <<stp>>).

4) Artefakte
4.1 Truth (maschinenlesbar)
	• todo.events.jsonl (append-only; 1 Zeile = 1 JSON-Objekt)
	• todo.state.json (klein; keine History)
	• handoff.latest.json (Resume-Anker + Capsule)
4.2 Views (menschenlesbar, abgeleitet)
	• todo.current.md (Dashboard; kurz)
	• handoff.latest.md (optional; aus JSON gerendert)
4.3 Debug (nur bei Bedarf)
	• terminal.out.log, terminal.err.log (nur bei Verify-/Build-/Lint-Fehlern oder Debug)
	• logs/handoff/handoff-<ts>.md (nur bei Signal #ci stp (Legacy: <<stp>>)/Milestone)

5) To-Do-System
5.1 todo.events.jsonl (History, Truth)
Pflicht: Single-Line-JSON, strikt valide.
Minimal-Schema (Pflichtfelder):
	• ts, event_id, todo_id, type, status, prio, source, msg, refs, changed, verified, git
Regel: pro Iteration genau 1 Event (Ausnahme: Signal #ci stp (Legacy: <<stp>>) kann zusätzlich 1 Sync-Event schreiben).
5.2 todo.state.json (State, Truth)
Enthält nur aktive Items (open|in-progress|blocked) + active_id + cursor.
Statusmodell:
	• Maximal 1× in-progress (Active).
5.3 todo.current.md (View)
Kurz, kein YAML, keine umfangreichen Tabellen. Active oben, Blocker/Next sichtbar.
Sanitize/Migration:
	• Legacy oder zu lang: <<cmd:todo-sanitize>>.
	• Missing/korrupt: <<cmd:todo-rebuild>>.
5.4 Masterliste (Überblick, einmal pro Chat)
	• todo.master.index.json (überschreibbar, Single-Line-JSON): 1 Eintrag pro To-Do mit todo_id, title, last_status, prio, tags, last_ts.
	• Wird beim Chat-Start einmal gelesen und danach nur bei Dateiänderung erneut gelesen.
5.5 Kompaktion (abgehandelte Tasks aus Views entfernen)
Ziel: todo.current.md und todo.state.json enthalten nur open|in-progress|blocked.
Trigger (bei Chat-Start und vor Signal #ci stp (Legacy: <<stp>>) prüfen):
	• todo.current.md enthält done/abgehandelte Items
	• todo.state.json enthält done (Formatfehler)
	• Rotation-Trigger (siehe 5.6)
Aktion (Signal: #ci todo-compact; Legacy: <<cmd:todo-compact>>):
	• Entferne done aus todo.state.json (falls vorhanden).
	• Rendere todo.current.md ausschließlich aus todo.state.json.
	• Aktualisiere todo.master.index.json (letzter Status pro To-Do).
5.6 Pruning + Rotation (Event-History minimal halten)
Ziel: todo.events.jsonl bleibt sehr klein; operative Arbeit basiert auf todo.state.json/todo.current.md.
Pruning-Regel (bei Chat-Start und vor Signal #ci stp (Legacy: <<stp>>) prüfen):
	• Wenn ein To-Do in todo.master.index.json oder todo.state.json als done markiert ist, dürfen dessen Events nicht in todo.events.jsonl verbleiben.
Aktion (Signal: #ci todo-prune; Legacy: <<cmd:todo-prune>>):
	1. Bestimme done_todo_ids aus todo.master.index.json (fallback: aus todo.state.json, falls Master fehlt).
	2. Verschiebe alle Events mit todo_id ∈ done_todo_ids nach logs/todo/done-events-<ts>.jsonl.
	3. Schreibe todo.events.jsonl neu mit nur noch Events zu aktiven To-Dos (open|in-progress|blocked) plus optionalem checkpoint-Event.
	4. Aktualisiere todo.history.digest.json (Single-Line-JSON): done_total, done_last_30d, recent_done (letzte 20), last_prune_ts.
Rotation-Trigger (bei Chat-Start und vor Signal #ci stp (Legacy: <<stp>>) prüfen):
	• todo.events.jsonl > 50 Zeilen oder > 25 KB oder älteste Events > 14 Tage
Rotation-Aktion (Signal: #ci todo-rotate; Legacy: <<cmd:todo-rotate>>):
	1. Schreibe todo.checkpoint.json (Single-Line-JSON): Kopie des aktuellen todo.state.json + checkpoint_event_id + history_archives.
	2. Verschiebe verbleibende alte Events nach logs/todo/active-events-<first_ts>--<last_ts>.jsonl.
	3. Erzeuge neue todo.events.jsonl:
		○ erste Zeile: type:"checkpoint" mit Verweis auf todo.checkpoint.json und history_archives.
		○ danach: nur die letzten N Events (Default: 30) seit Checkpoint.
	4. Aktualisiere todo.history.digest.json: last_rotation_ts.
	5. Aktualisiere todo.state.json: checkpoint_event_id, history_archives.
Rebuild-Regel:
	• Rebuild erfolgt aus todo.checkpoint.json + aktuellem todo.events.jsonl.
	• Archive werden nur bei forensischer Analyse eingelesen.
Chat-Start-Read-Regel:
	• todo.events.jsonl wird nicht eingelesen, außer für todo-prune, todo-rotate oder todo-rebuild.
	• Pro Aktion (todo-prune/todo-rotate/todo-rebuild) wird todo.events.jsonl maximal 1× gelesen (kein Re-Read in derselben Aktion).
	• Rotation-Trigger sollen bevorzugt über Dateimetadaten (Größe/mtime) bestimmt werden, nicht über Vollscan.
	• Manual wird nach Erstellung/Prüfung von manual.digest.json nicht erneut eingelesen, außer bei Dateiänderung.
	• env-inventory wird nach Erstellung/Prüfung von env_inventory.digest.json nicht erneut eingelesen, außer bei Dateiänderung.
	• todo.history.digest.json wird genau einmal gelesen, danach nur bei Dateiänderung.

6) Logging
6.1 Prinzip
	• Truth ist JSON/JSONL. Andere Formate sind Views oder Debug.
	• Keine doppelten Wahrheiten.
	• Default ist minimal: Digests statt Voll-Logs.
6.1.1 Minimale Diagnose-Artefakte (überschreibbar)
	• logs/verify/verify.digest.json (siehe 7.0)
Voll-Logs (logs/verify/verify-<ts>.log) nur ab Eskalationsstufe 1 oder bei verify_profile:deep.
6.2 chat-history.log (Pointer-Log)
Single-Line-JSON, 1 Zeile pro Iteration oder pro Signal #ci stp (Legacy: <<stp>>):
{"ts":"...","event_id":"EV-...","todo_id":"TD-...","summary":"...","refs":["file:todo.events.jsonl","file:handoff.latest.json"]}
6.3 Terminal-Logs
Standard: keine dauerhaft wachsenden Terminal-Logs. Nur bei Fehlern/Debug erzeugen.
6.4 Sperrregel bei Meta-Schleifen
Sofort blocked + Signal #ci stp (Legacy: <<stp>>), wenn:
	• letzte 5 Aktionen nur Meta-Dateien
	• Meta-Dateien 2× hintereinander ohne Code/Command/Verify
	• todo.events.jsonl >1 Append pro Iteration
	• todo.state.json oder todo.current.md mehrfach pro Iteration geschrieben
6.5 Loop-Guard (Chat/Terminal, deterministisch, log-sparend)
6.5.1 Signal #ci loop / <<loop>> (Loop-Intervention, höhere Warte)
Ziel: Endlosschleifen aktiv beenden, Problem abstrahieren, 1 intelligenten, deterministischen Schritt wählen.
Trigger:
	• User sendet #ci loop oder <<loop>>.
Protokoll (Pflicht, kurz):
	1. Freeze: keine weiteren Retries/Commands ausführen.
	2. Loop-Snapshot: last_cmd, last_fail_signature, repeat_count aus .ci/run/loop.guard.json (falls vorhanden) in Digest übernehmen.
	3. Abstraktion: Problem in 1 Satz (Symptom → Blocker).
	4. Hypothesen-Ranking: max 3 Ursachen, jede mit Decisive Check (read-only) und Fix.
	5. Choose-One: genau 1 Fix-Schritt auswählen (oder blocked, wenn Checks/Fix nicht möglich).
	6. Token-Budget: Ausgabe max. 180 Wörter; kein Wiederholen von Logs.
	7. Danach optional #ci stp (Scheunentorprotokoll), wenn für Übergabe nötig.
Fail-Regel:
	• Wenn nach #ci loop kein eindeutiger nächster Schritt ableitbar ist: blocked + Evidence + #ci stp (Sync).
Ziel: Wiederholschleifen automatisch beenden und in einen reproduzierbaren Zustand bringen.
State (überschreibbar): .ci/run/loop.guard.json (Single-Line-JSON)
	• ts, agent_id, last_cmd, last_fail_signature, repeat_count, last_progress (changed|evidence|blocked).
Regeln:
	• Wenn repeat_count >= 2 bei gleichem last_cmd oder gleicher last_fail_signature: keine weiteren Retries.
	• Aktion: blocked + Evidence (Digest) + #ci stp.
	• repeat_count wird nur in Meta-Flush aktualisiert (1× pro Iteration).

7) Verify + Git
7.0 Fehlerklassifikation (deterministisch, log-sparend)
Priorität (wenn mehrere Fehler gleichzeitig auftreten):
	1. Infra/Tooling (Wrapper fehlt, JDK fehlt, Timeout) → blocked
	2. Tests/Lint → normales Fixing
Regel:
	• Wenn Infra/Tooling-Fehler und Tests gleichzeitig fehlschlagen: erst Infra/Tooling lösen, dann Verify erneut; erst danach Tests bearbeiten.
Minimaler Digest (pro Verify-Run, überschreibbar):
	• logs/verify/verify.digest.json (Single-Line-JSON): ts, cmd, exit, fail_signature, failed_tasks(max 5), tests_failed_count?.
7.0.1 Dependency-Bootstrap (autonom, token-sparend)
Ziel: fehlende, notwendige System-Tools deterministisch erkennen und (wenn möglich) automatisch nachinstallieren, ohne Prompts.
Grundregeln:
	• Nur installieren, wenn ein Verify/Run-Command sonst sicher scheitert (z.B. node fehlt für Kotlin/JS).
	• Bevorzugt Wrapper/Projekt-Tooling; System-Install nur für Runtime-Dependencies (JDK, Node, Git, Python).
	• Jede Installation muss non-interactive sein; bei Prompt → abbrechen und blocked.
Gradle-Regel (gegen Drift/Versionskonflikte):
	• Nie globales Gradle installieren, wenn gradlew(.bat) existiert.
	• Wenn kein Wrapper existiert und Build-System=Gradle:
		○ nur installieren, wenn toolchain.pins.md eine gradle_version pinnt.
		○ sonst: blocked (Wrapper fehlt) + reproduzierbare Bootstrap-Schritte.
Erkennung (minimal):
	• OS ermitteln.
	• choco vorhanden? (Windows) → Autoinstall möglich.
	• Benötigte Tools ableiten aus Build-System (siehe 8.1):
		○ Gradle (Kotlin/JVM): java
		○ Gradle (Kotlin/JS, Compose Web): java + node
		○ Node-Projekt: node
		○ Python-Server/Tools: python
		○ Git-Operationen: git
Checks (read-only):
	• java -version, node -v, python --version, git --version.
	• Wenn Wrapper vorhanden: gradlew(.bat) --version --console=plain (Kompatibilitätscheck).
Java/Gradle-Kompatibilität (Pflicht, bei Wrapper):
	• Wenn gradlew --version fehlschlägt and Output eine der Signaturen enthält:
		○ This version of Gradle requires Java / Unsupported class file major version / has been compiled by a more recent version of the Java Runtime
		○ dann gilt: Java ist inkompatibel → Java-Repair ausführen (siehe unten) und danach gradlew --version erneut.
Autoinstall (Windows, wenn choco):
	• JDK (Default LTS): choco install temurin17 -y --no-progress
	• Node LTS: choco install nodejs-lts -y --no-progress
	• Git: choco install git -y --no-progress
	• Python: choco install python -y --no-progress
Java-Repair (Windows, deterministisch, ohne Neustart der Shell):
	1. Ziel-Java bestimmen:
		○ primär: toolchain.pins.md (java_major), sonst Default 17, Fallback 21.
	2. Wenn mehrere java.exe auf PATH:
		○ Kandidaten via where.exe java sammeln.
		○ für jeden Kandidaten "<path>" -version ausführen und Major ableiten.
		○ wähle Kandidat mit ziel_major (oder nächstkleiner erlaubter); sonst installiere das Ziel-JDK.
	3. Prozess-scope fix (damit Gradle in derselben Session das richtige Java nutzt):
		○ JAVA_HOME auf den gewählten JDK-Root setzen.
		○ PATH im Prozess prepend: $env:JAVA_HOME in;....
	4. Danach zwingend: java -version + gradlew --version (Exitcode 0 = ok).
Post-Install Validierung (für jede Nachinstallation, Pflicht):
	• Nach jedem Install/Repair sofort:
		○ Versions-Command erneut ausführen (java -version, node -v, ...).
		○ bei Wrapper: gradlew --version muss Exit 0 sein.
	• Wenn Validierung fehlschlägt: blocked + Evidence (Exitcode + Tail) + reproduzierbare Commands.
Fail-Regel:
	• Wenn Install/Check fehlschlägt (Exit≠0, fehlende Rechte, Proxy): blocked + Evidence (Exitcode + Tail) + reproduzierbare Install-Commands.
Signal:
	• #ci deps-bootstrap → führt Checks + (falls nötig) Install aus, schreibt nur Digest (z.B. in logs/verify/verify.digest.json und CAPSULE deps_bootstrapped:[..]).
7.0.2 Buildscript-Compile Triage (Gradle Kotlin DSL)
Ziel: Fehler in build.gradle.kts/Plugin-DSL deterministisch beheben, ohne Trial-and-Error-Schleifen.
Fail-Signaturen (Beispiele):
	• Function invocation 'browser()' expected
	• Unresolved reference: webpackTask / developmentWebpackTask
	• Unresolved reference: IR
Regeln:
	• Keine Retries mit identischer fail_signature ohne Änderung (Loop-Guard gilt).
	• Keine Reflection/Typ-Referenzen auf interne Targets (z.B. KotlinJsIrTarget::IR).
	• Keine direkten DSL-Accessors außerhalb des kotlin { js(IR) { browser { ... } } }-Scopes.
Deterministischer Fix (minimal, universal):
	1. Task-Referenzen per Name statt DSL-Objekten:
		○ Verwende tasks.named("jsBrowserDevelopmentWebpack"), tasks.named("jsBrowserProductionWebpack"), tasks.named("jsBrowserDevelopmentRun") (oder browserDevelopmentWebpack in Single-Target-Projekten).
	2. Wenn ein Custom-Task bisher dependsOn(kotlin.js().browser.*) nutzt:
		○ Ersetze durch dependsOn("jsBrowserDevelopmentWebpack") (Build) oder dependsOn("jsBrowserDevelopmentRun") (Dev-Server).
	3. Wenn index.html Multi-Script erwartet, aber das Projekt Bundle liefert:
		○ siehe 8.6.3 (Serve-Triage) und bevorzuge Bundle-Outputs.
	4. Nach Patch immer Verify ausführen (mindestens :web:compileKotlinJs oder check).
Block-Regel:
	• Wenn nach 1 Patch + 1 Verify das Buildscript weiterhin nicht kompiliert: blocked + Evidence (fail_signature + betroffene Zeilen) + #ci stp.
7.1 Verify (Pflicht)
7.1.1 Preflight (minimal)
Signal: #ci preflight (führt diesen Block sofort aus).
Wenn preflight:standard|strict:
	• immer: gradlew(.bat) --stop (non-interactive).
	• wenn deps_bootstrap:auto: #ci deps-bootstrap (best effort; nur wenn Tools fehlen)
Preflight schreibt nur logs/verify/verify.digest.json (kein riesiges Log).
7.1.2 Verify-Run
Ziel: Compile + Lint + Tests (und Build, wenn vorhanden) mit reproduzierbarem Evidence.
Grundregeln:
	• Verify gilt nur als bestanden, wenn Exitcode 0 und Evidence vorhanden ist.
	• Evidence wird in verified[] (Event + CAPSULE) dokumentiert.
	• Verify-Kommandos laufen non-interactive (--console=plain), ohne Pager/Prompts.
Verify-Profile:
	• verify_profile: standard (Default)
		○ nutzt Caching/Inkrementalität
	• verify_profile: deep
		○ erzwingt Neulauf bei Verdacht auf Tooling-/Index-Mismatch
Diagnose-Eskalation (staged, log-sparend):
	• Steuerung über verify_escalation:
		○ staged (Default): Flags nur bei wiederholtem Fail oder explizit „deep“.
		○ off: keine automatische Eskalation; nur Standard/Deep-Kommandos.
Begriffe:
	• fail_signature: aus Output ableitbar (erstes fehlschlagendes Task-Label + Exception-Klasse/Message-Kern).
	• fail_streak: Anzahl aufeinanderfolgender Fails mit identischer fail_signature.
Eskalationsleiter (nur wenn verify_escalation: staged):
	1. Erster Fail (fail_streak=1):
		○ wiederhole mit --stacktrace
	2. Wiederholter Fail (fail_streak=2):
		○ wiederhole mit --stacktrace --info
	3. Dritter gleicher Fail oder Performance-Hinweis (fail_streak>=3 oder „hängt/ewig“):
		○ optional --scan (nur wenn non-interactive möglich); sonst blocked + Hinweis
	4. --debug:
		○ nur bei verify_profile: deep und nur wenn fail_streak>=3 und Ursache weiterhin unklar
		○ maximal 1 Versuch; Output ausschließlich in Logdatei
Log-Policy (Eskalation):
	• Standard-Verify: keine dauerhaften Terminal-Logs.
	• Ab Eskalationsstufe 1: schreibe Vollausgabe in logs/verify/verify-<ts>.log und speichere nur Tail (letzte 120 Zeilen) in terminal.err.log.
	• Rotation: wenn terminal.err.log > 50 KB, verschiebe nach logs/terminal/terminal.err-<ts>.log und starte neu.
Gradle (Wrapper vorhanden):
	• Standard:
		○ Windows/PowerShell: gradlew.bat check --console=plain
		○ Unix: ./gradlew check --console=plain
	• Deep:
		○ Windows/PowerShell: gradlew.bat clean check --no-build-cache --rerun-tasks --console=plain
		○ Unix: ./gradlew clean check --no-build-cache --rerun-tasks --console=plain
Gradle (Eskalationsflags, nur staged):
	• Stufe 1: --stacktrace
	• Stufe 2: --stacktrace --info
	• Stufe 3: --scan (falls zulässig) oder --stacktrace --info beibehalten
	• Stufe 4: --debug --stacktrace (nur deep)
Evidence (Gradle): mindestens eines der folgenden Artefakte muss existieren und frisch sein (mtime ≥ Verify-Start):
	• */build/test-results/test/*.xml oder */build/reports/tests/test/index.html
	• bei reinen Compile-Schritten: */build/classes/kotlin/* (mtime ≥ Verify-Start)
7.1.3 Browser-Smoke (Web, regelmäßig, non-interactive)
Ziel: minimale Browser-Kompatibilität sicherstellen, ohne echte UI-Interaktion.
Bindend, wenn browser-tests.contract.md vorhanden ist (Quellenhierarchie 3.1).
Trigger (wenn browser_tests: staged):
	• jede browser_test_interval Iterationen oder
	• wenn changed[] Pfade unter web/ oder ui/ enthält oder
	• vor #ci stp, wenn seit dem letzten Smoke-Run Web-Dateien geändert wurden.
Prozedur (deterministisch):
	1. Build: Production-Webpack bevorzugen (max 3 Versuche, feste Reihenfolge):
		○ :web:jsBrowserProductionWebpack
		○ :web:browserProductionWebpack
		○ :web:jsBrowserDevelopmentWebpack
(alle mit --console=plain; bei „Task not found“ → nächster Versuch; sonst Fail.)
	2. Serve-Root bestimmen (read-only):
		○ Kandidaten in Priorität:
			§ web/build/dist/js/productionExecutable/
			§ web/build/kotlin-webpack/js/productionExecutable/
			§ web/build/processedResources/js/main/ (Multi-Script)
		○ wähle ersten existierenden Ordner, der index.html enthält; sonst blocked.
	3. Server starten (detached): #ci pyserver-start (Server muss den ermittelten Root serven; falls pyserver-start noch fix ist → via cwd anpassen).
	4. Smoke-Checks (max 10 Assets):
		○ GET / muss 200 liefern.
		○ parse index.html nach src="...\.js" und src="...\.wasm".
		○ für jedes Asset: GET <asset> muss 200 liefern und Content-Type darf für .js/.wasm nicht text/html sein.
	5. Server stoppen: #ci pyserver-stop.
Evidence (minimal):
	• logs/verify/browser.smoke.digest.json (Single-Line-JSON): ts, served_root, url, assets_checked(max10), failures(max5), exit.
Fail-Regel:
	• Bei Fail: kein Commit/Push; blocked + Evidence + reproduzierbare Commands.
Signal:
	• #ci browser-smoke → führt 7.1.3 jetzt aus.
Bei IDE-/Language-Server-Diagnosen (z.B. „unresolved reference“):
	• Wenn check/compileTestKotlin grün ist, gelten IDE-Probleme als nicht-verbindlich.
	• Wenn grün, aber Verdacht bleibt: verify_profile: deep ausführen.

7.1.4 UI-Layout-Check (Visual Regression + UI-Lint, non-interactive)
Ziel: Layoutfehler automatisiert finden (Overlap/Overflow/Clipping) und visuelle Abweichungen gegen Baseline erkennen.
Voraussetzungen: node + Playwright (tools/ui), ImageMagick (magick in PATH).
Trigger (wenn browser_tests: staged):
	• wenn changed[] Pfade unter web/, ui/, assets/ oder styles/ enthält oder
	• vor #ci stp, wenn seit dem letzten UI-Check Run entsprechende Dateien geändert wurden.
Prozedur (deterministisch, best effort):
	1. Build + Serve: identisch zu 7.1.3 (Root-Ermittlung); Server auf 127.0.0.1.
	2. Headless Chromium lädt die App pro Viewport.
	3. Screenshot pro Viewport (Default: 1366×768, 1920×1080).
	4. UI-Lint (Heuristiken; optional via Config-Selektoren): 
		○ Text-Overflow (scrollWidth>clientWidth / scrollHeight>clientHeight)
		○ Overlap zwischen definierten Regionen (z.B. topbar/board/sidebars)
		○ Out-of-Viewport/Container-Clipping (BoundingBox außerhalb Viewport/Parent)
	5. Visual Diff gegen Baseline (ImageMagick `magick compare -metric AE`).
Baseline:
	• liegt in ui/baseline/<viewport>.png (ins Repo einchecken).
Evidence (minimal):
	• logs/ui/ui.lint.json (Findings; pro Viewport, max 100)
	• logs/ui/ui.visual.digest.json (AE pro Viewport + exit)
	• logs/ui/screens/*.png, logs/ui/diff/*.png (bei Diff)
Fail-Regel:
	• Bei baseline missing oder AE > threshold oder Findings severity=high: kein Commit/Push; blocked + Evidence.
Signale/Commands:
	• #ci ui-check		—	UI-Layout-Check ausführen (7.1.4)
	• #ci ui-baseline	—	Baseline erzeugen/überschreiben aus aktuellem Stand
	• #ci ui-roadmap	—	Findings → logs/ui/roadmap.ui.md (ankreuzbar)

## Browser-Drift Rueckfragepflicht

Wenn ein sichtbarer UI-Fehler im Browser gemeldet wird und mindestens einer der folgenden Punkte zutrifft, muss vor jedem Fix aktiv nach dem realen User-Viewport gefragt werden:

- der gemeldete Viewport ist nicht explizit Teil der aktuellen Guard-/Viewport-Matrix
- vorhandene fokussierte Tests sind gruen, das Userbild aber weiter rot
- derselbe Fehlertyp taucht ueber mehrere Chats erneut auf, ohne dass der reale Browserzustand sauber reproduziert wurde

Die Rueckfrage muss mindestens diese Angaben einsammeln:

- Browser-Viewport, zum Beispiel `1440x900`
- Browser-Zoom, zum Beispiel `100%`
- relevante DPR-/Display-Skalierung oder OS-Skalierung, falls bekannt
- nach Moeglichkeit ein Screenshot der Browser-Viewportleiste oder Devtools-Device-Toolbar

Verbindliche Arbeitsreihenfolge in solchen Faellen:

1. realen User-Viewport verifizieren
2. passenden Red-Gate fuer genau diesen Viewport bauen
3. Produktfix gegen diesen bestaetigten Zustand umsetzen
4. den verifizierten Viewport dauerhaft in den passenden UI-Funktionstests mitfuehren

Ein lokaler Green-Path ohne bestaetigten User-Viewport gilt bei sichtbarem Browserdrift nicht als ausreichende Entwarnung.

7.2 Route-Check (Pflicht vor Commit)
Ziel: prüfen, ob die gewählte Umsetzung mit den bindenden Vorgaben (README/Roadmap/Contract/Manual) konsistent ist.
Scope:
	• basiert auf Artefakten (Quellenhierarchie) und Diff/Dateiliste.
	• keine neue Planung, keine Hypothesen.
Route-Check-Profil:
	• route_check: standard (Default)
		○ prüft harte No-Gos/Policies aus Contract/Manual
		○ prüft Pfad-/Import-Verbote (falls definiert)
		○ prüft Verify-Evidence vorhanden
	• route_check: strict
		○ zusätzlich: greift auf projektweite schnelle Suchen/Lints zurück (nur read-only)
	• route_check: off
		○ nur zulässig für lokale Experimente; nicht für Merge/Release.
Ausgabe (intern + in CAPSULE):
	• route_ok: true|false
	• route_violations: [..] (max. 5 Einträge)
Fail-Regel:
	• Bei route_ok:false: kein Commit/Push; Status blocked mit reproduzierbaren Hinweisen.
7.3 Git (Pflicht)
	• Nur intendierte Änderungen (git status kontrollieren).
	• Commit nur wenn Verify grün.
	• Push wenn Remote vorhanden; sonst blocked + konkrete Anleitung.
7.3.1 Patch-Apply (git apply, deterministisch, non-interactive)
Ziel: Patches reproduzierbar anwenden, ohne manuelle Terminal-Interaktion.
Patch-Ablage (konventionell):
	• Primär: .ci/patches/*.patch
	• Optional Inbox: .ci/inbox/*.patch
Regeln:
	• Pro Iteration maximal 1 Patch anwenden.
	• Vor Patch-Apply muss der Working Tree clean sein (git status --porcelain leer). Sonst: blocked + Evidence.
	• Immer zuerst Dry-Run: git apply --check <patch>.
	• Wenn Dry-Run ok: git apply <patch>.
	• Danach Patch nach logs/patches/applied-<ts>.patch verschieben (oder löschen, wenn Logs nicht erlaubt).
	• Danach Verify (mind. check oder projektspezifischer Verify-Command). Kein Commit ohne grün.
Auswahlregel, wenn mehrere Patches vorhanden:
	• Wenn genau 1 Patch vorhanden: den anwenden.
	• Wenn >1 Patch vorhanden: blocked + Liste der Kandidaten (kein Raten).
Evidence (minimal):
	• In logs/verify/verify.digest.json: cmd:"git apply", exit, fail_signature?.
	• In CAPSULE: changed[] (geänderte Files) + verified[] nach Verify.
Signal:
	• #ci patch-apply (Legacy: <<cmd:patch-apply>>) → wendet Patch nach obiger Regel an.
Non-interactive Git (Pflicht):
	• Für alle Git-Kommandos Pager/Interaktivität deaktivieren.
	• Standardpräfix:
		○ git -c core.pager=cat -c color.ui=false --no-pager <cmd> ...
	• Kommandos mit großem Output (z.B. git show <rev>:<path>) dürfen nicht „live“ im Terminal ausgegeben werden:
		○ Ausgabe in Datei umleiten und anschließend Datei lesen/verarbeiten.
Einschränkungen:
	• Kein History rewrite (reset/rebase/commit --amend), kein force-push, kein mass refactor ohne explizite Anweisung.

8) Tool-Discovery + Terminal-Regeln
8.0 Datei-Lesen Fallback (Autonomie, kein Nachfragen)
Wenn ein File-Read unerwartet fehlschlägt (z.B. Tool liefert Verzeichnisliste statt Dateiinhalt):
	• nicht nachfragen.
	• Fallback über Terminal (non-interactive):
		○ Windows/PowerShell: Get-Content -Raw <path>
		○ Windows/cmd: type <path>
		○ Unix: cat <path>
Für große Dateien: nur Get-FileHash/sha256sum + stat/Get-Item nutzen.
8.1 Build-System erkennen
Gradle/Maven/npm/pnpm/yarn/etc.; Wrapper bevorzugen.
8.2 env-inventory as Tooling-Quelle
	• Aus env-inventory.snapshot.md: Shell-Info, JAVA_HOME, SDK-Pfade, PATH-Hinweise, Gradle-Verzeichnis.
	• Bei Nutzung: env_inventory.digest.json (Single-Line-JSON) ist die bevorzugte Kurzquelle.
	• Bei altem Snapshot (generated_at >30 Tage): in todo.state.json ein open anlegen: refresh env-inventory.
8.3 Non-interactive Terminal
	• Pager aus, Prompts aus, stabile Workdir.
	• Long-running Prozesse: watchdog + definierte Abbruchbedingung.
Hard-Guard (Long-Running Tasks, gegen Tool-Runner-Hänger):
	• Wenn ein geplanter Terminal-Command eines der Tokens enthält:
		jsBrowserDevelopmentRun | wasmJsBrowserDevelopmentRun | browserDevelopmentRun | python -m http.server | runWeb
		webpack serve | webpack-dev-server | webpack.js serve | serve --config *webpack*.config.js
		○ nicht ausführen.
		○ deterministisch umleiten auf #ci devserver-start (Gradle Dev-Server) oder #ci pyserver-start (Python Static Server).
Interactive-Prompt-Guard (keine Hänger):
	• Wenn Output Prompts enthält (z.B. Batchvorgang abbrechen (J/N)?, Press any key, Password, Continue?):
		○ Command sofort abbrechen.
		○ deterministisch auf non-interactive Variante wechseln (Flags/Env) oder blocked.
Zusatz: Tool-Runner/UI-Confirmations (z.B. „Proceed While Running“, „Continue?“, „Press any key“)
	• Wenn der Runner eine Bestätigung verlangt, gilt das als Prompt.
	• Sofort abbrechen und deterministisch umstellen:
		○ Long-running Prozesse niemals foreground starten (siehe 8.6).
		○ Output immer umleiten (Datei) und detached starten.
Tool-Runner-Execute-Guard (Sixth/Runner-Confirmations):
	• Wenn die UI vor Ausführung nach Bestätigung fragt (z.B. „Sixth wants to execute this command“):
		○ KEINE Terminal-Ausführung über den Runner starten.
		○ Stattdessen: nur #ci Signale verwenden ODER den Command als „USER-RUN“ ausgeben (Copy/Paste), ohne weitere Rückfragen.
Ausnahme (Long-Running Services):
	• Dev-Server/Watcher (z.B. :web:jsBrowserDevelopmentRun) dürfen nicht in der Verify-Phase laufen.
	• Gilt ebenso für lokale Static-Server (z.B. python -m http.server).
	• Start/Stop nur über #ci devserver-start/#ci devserver-stop (Hintergrund + PID-Datei + log-sparend).
	• Der Agent darf den User nicht zur manuellen Prozessbeendigung auffordern. Wenn keine PID-Datei vorhanden ist: Stop-Fallback über Port-/Process-Scan (siehe Stop-Skripte in 8.6/8.6.1).
8.6 Dev-Server im Hintergrund (Gradle/Kotlin/JS)
Problem: Tasks wie :web:jsBrowserDevelopmentRun laufen absichtlich „endlos“ (webpack-dev-server) und blockieren sonst das Terminal.
Wichtig (Autonomie in MCP/Tool-Runner UIs):
	• Solche Commands dürfen nie „foreground“ gestartet werden, sonst wartet der Runner auf Prozessende (UI zeigt oft „Proceed While Running“).
	• Deshalb: Devserver-Start immer detached (Start-Process/nohup). clean ist dafür verboten (separat laufen lassen, wenn nötig).
Regeln:
	• Start nur, wenn kein laufender Devserver registriert ist.
	• Zustand in .ci/run/devserver.pid.json (Single-Line-JSON): ts, pid, cmd, cwd, port, url.
	• Output in logs/devserver/devserver.log (append) mit Rotation: >200 KB → nach logs/devserver/devserver-<ts>.log verschieben.
	. wenn die Server funktionieren, lasse sie laufen um zeit zu sparen.
	
Windows PowerShell (Start, detached, guard+cleanup):
# Guard: falls PID-Datei existiert oder Port 8090 belegt ist → stop
if (Test-Path .ci/run/devserver.pid.json) { try { $j = Get-Content -Raw .ci/run/devserver.pid.json | ConvertFrom-Json; Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue } catch {} ; Remove-Item .ci/run/devserver.pid.json -ErrorAction SilentlyContinue }
$pidExisting = (Get-NetTCPConnection -LocalPort 8090 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
if ($pidExisting) { Stop-Process -Id $pidExisting -Force -ErrorAction SilentlyContinue }

New-Item -ItemType Directory -Force .ci/run, logs/devserver | Out-Null
$cmd = "./gradlew :web:jsBrowserDevelopmentRun --console=plain"
$log = "logs/devserver/devserver.log"
if (Test-Path $log) { if ((Get-Item $log).Length -gt 200kb) { Move-Item $log ("logs/devserver/devserver-"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log") } }
$p = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd -WorkingDirectory (Get-Location) -RedirectStandardOutput $log -RedirectStandardError $log -PassThru -WindowStyle Hidden
@{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$cmd; cwd=(Get-Location).Path; port=8090; url="http://localhost:8090/" } | ConvertTo-Json -Compress | Set-Content -NoNewline .ci/run/devserver.pid.json
Windows PowerShell (Stop, inkl. Fallback):
```powershell
# 1) Primär: PID-Datei
if (Test-Path .ci/run/devserver.pid.json) {
  $j = Get-Content -Raw .ci/run/devserver.pid.json | ConvertFrom-Json
  Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue
  Remove-Item .ci/run/devserver.pid.json -ErrorAction SilentlyContinue
  return
}
# 2) Fallback: Port 8090 (webpack-dev-server Default)
$pid = (Get-NetTCPConnection -LocalPort 8090 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
if ($pid) { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue }
# 3) Cleanup
Remove-Item .ci/run/devserver.pid.json -ErrorAction SilentlyContinue
Unix (Start, detached):
mkdir -p .ci/run logs/devserver
log="logs/devserver/devserver.log"
[ -f "$log" ] && [ $(wc -c <"$log") -gt 204800 ] && mv "$log" "logs/devserver/devserver-$(date +%Y%m%d-%H%M%S).log"
nohup ./gradlew :web:jsBrowserDevelopmentRun --console=plain >>"$log" 2>&1 &
pid=$!
printf '{"ts":"%s","pid":%s,"cmd":"%s","cwd":"%s","port":8090,"url":"http://localhost:8090/"}' "$(date -Iseconds)" "$pid" "./gradlew :web:jsBrowserDevelopmentRun --console=plain" "$(pwd)" > .ci/run/devserver.pid.json
Unix (Stop):
pid=$(grep -o '"pid":[0-9]*' .ci/run/devserver.pid.json 2>/dev/null | head -n1 | cut -d: -f2)
[ -n "$pid" ] && kill -9 "$pid" 2>/dev/null || true
rm -f .ci/run/devserver.pid.json
Signals:
	• #ci devserver-start → Start (OS-abhängig) + PID-Datei + log-rotation
	• #ci devserver-stop → Stop via PID-Datei
8.6.1 Python Static Server im Hintergrund
Problem: python -m http.server blockiert interaktiv; -NoNewWindow hängt am aktuellen Terminal und ist deshalb ungeeignet.
Wichtig (Autonomie in MCP/Tool-Runner UIs):
	• Python-Server niemals foreground starten, sonst wartet der Runner.
	• Start immer detached (Start-Process/nohup) + PID-Datei.
Regeln (minimal):
	• Zustand in .ci/run/pyserver.pid.json (Single-Line-JSON): ts, pid, cmd, cwd, port, url.
	• Output in logs/devserver/pyserver.log (append) mit Rotation: >200 KB → nach logs/devserver/pyserver-<ts>.log.
	• Start nur, wenn keine PID-Datei existiert; sonst zuerst #ci pyserver-stop.
Windows PowerShell (Start, detached, aus Unterordner):
New-Item -ItemType Directory -Force .ci/run, logs/devserver | Out-Null
$cwd = "web/build/processedResources/js/main"
$port = 8000
$cmd = "python -m http.server $port --bind 127.0.0.1"
$log = "logs/devserver/pyserver.log"
if (Test-Path $log) { if ((Get-Item $log).Length -gt 200kb) { Move-Item $log ("logs/devserver/pyserver-"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log") } }
$p = Start-Process -FilePath "python" -ArgumentList "-m","http.server","$port","--bind","127.0.0.1" -WorkingDirectory $cwd -RedirectStandardOutput $log -RedirectStandardError $log -PassThru -WindowStyle Hidden
@{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$cmd; cwd=$cwd; port=$port; url="http://127.0.0.1:$port/" } | ConvertTo-Json -Compress | Set-Content -NoNewline .ci/run/pyserver.pid.json
Windows PowerShell (Stop, inkl. Fallback):
# 1) Primär: PID-Datei
if (Test-Path .ci/run/pyserver.pid.json) {
  $j = Get-Content -Raw .ci/run/pyserver.pid.json | ConvertFrom-Json
  Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue
  Remove-Item .ci/run/pyserver.pid.json -ErrorAction SilentlyContinue
  return
}
# 2) Fallback A: Prozess-Scan (python http.server)
Get-CimInstance Win32_Process |
  Where-Object { $_.Name -match '^python(3)?\.exe$' -and $_.CommandLine -match 'http\.server' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
# 3) Fallback B: Port-Scan (Default 8000)
$pid = (Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
if ($pid) { Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue }
# 4) Cleanup
Remove-Item .ci/run/pyserver.pid.json -ErrorAction SilentlyContinue
Unix (Start/Stop): analog zu 8.6 mit nohup + PID-Datei (Name: pyserver.pid.json).
Signals:
	• #ci pyserver-start → Start (OS-abhängig) + PID-Datei + log-rotation
	• #ci pyserver-stop → Stop via PID-Datei
8.6.2 Kotlin/JS Module-Loader Triage (weißer Screen)
Symptom (Browser-Console):
	• Error loading module 'X'. Its dependency 'Y' was not found. Please, check whether 'Y' is loaded prior to 'X'.
Deterministische Ursache:
	• Y-Script wurde nicht geladen oder ist nicht im kotlin/-Ordner verfügbar/served.
Fix-Regel (minimal, ohne Webpack-Hacks):
	1. Nie build/**/webpack.config.js editieren (generiert, wird überschrieben).
	2. web/src/main/resources/index.html so patchen, dass Script-Reihenfolge stimmt:
		○ kotlin/kotlin.js zuerst
		○ dann fehlende Abhängigkeit kotlin/<Y>.js
		○ dann kotlin/<X>.js
		○ zuletzt App-Entry kotlin/<web-module>.js oder kotlin/<app>.js
	3. Wenn kotlin/<Y>.js nicht existiert:
		○ :web:jsProcessResources ausführen
		○ danach im Output-Verzeichnis nach <Y>.js suchen; fehlt es weiterhin → Gradle-Dependency/Resources-Setup ist defekt (Status blocked + Evidence).
Optional UI (keine Kotlin-Abhängigkeit):
	• In index.html ein kleines Error-Overlay einbauen (window.onerror), damit nicht nur „weiß“ angezeigt wird.
8.6.3 Kotlin/JS Webpack-Bundle Serve Triage (404/MIME text/html)
Symptom (Browser-Konsole):
	• kotlin/kotlin.js (oder weitere kotlin/*.js) → 404
	• „Refused to execute script … MIME type 'text/html'“ (Server liefert Fallback-HTML statt JS)
Deterministische Ursache:
	• index.html referenziert ein Multi-Script Layout (kotlin/*.js), aber der Build produziert ein Bundle Layout (z.B. web.js/*.wasm) oder die Assets liegen in einem anderen Output-Verzeichnis.
Fix-Regel (minimal, ohne Raten):
	1. Output-Art bestimmen (read-only):
		○ existiert web/build/kotlin-webpack/js/**/web.js oder web/build/dist/js/**/web.js → Bundle Layout.
		○ existiert **/kotlin/kotlin.js → Multi-Script Layout.
	2. Wenn Bundle Layout:
		○ index.html so patchen, dass es web.js lädt (und keine kotlin/*.js).
		○ Static-Server/Dev-Server Root auf das Verzeichnis setzen, das web.js enthält (z.B. web/build/dist/js/productionExecutable/ oder .../developmentExecutable/).
	3. Wenn Multi-Script Layout:
		○ Stelle sicher, dass kotlin/ im served Root existiert.
		○ Falls nicht: :web:jsProcessResources (oder passende Resource-Task) ausführen and dann erneut prüfen.
No-Go:
	• Kein „Blind-Copy“ von Build-Artefakten in processedResources, wenn dadurch Build-Skripte brechen (siehe 7.x Buildscript-Triage). Prefer: richtige Gradle-Tasks/Outputs + korrekte Server-Root.

8.7 Git-Output-Policy (Hänger vermeiden)
	• git show/git diff/git log -p nur mit Pager deaktiviert und vorzugsweise ohne große Terminal-Ausgabe.
	• Default: Git-Output immer in Datei umleiten; danach Datei lesen/verarbeiten (verhindert Runner-Hänger und Pager-Fallen).

Beispiel (PowerShell, git log --stat Roadmap.md, limitiert, Output→Datei):
$out = ".ci/tmp/gitlog-roadmap.stat.txt"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
git -c core.pager=cat -c color.ui=false --no-pager log --stat --max-count=25 -- Roadmap.md | Out-File -Encoding utf8 -NoNewline $out
# danach: Get-Content -Raw $out

PowerShell-Template (Datei aus Commit holen):
$rev="<hash>"; $p="store/src/main/kotlin/.../Reducer.kt"; $out=".ci/tmp/Reducer.kt@$rev"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
git -c core.pager=cat -c color.ui=false --no-pager show "$rev:$p" | Out-File -Encoding utf8 -NoNewline $out
Bash-Template:
rev="<hash>"; p="store/src/main/kotlin/.../Reducer.kt"; out=".ci/tmp/Reducer.kt@$rev"
mkdir -p "$(dirname "$out")"
git -c core.pager=cat -c color.ui=false --no-pager show "$rev:$p" > "$out"
Hinweis: Wenn ein Tool/Extension auf „vollständige Ausgabe“ wartet, darf der Agent nicht blockieren, sondern muss auf Datei-Redirect wechseln.

9) Observer Drift-Check (gegen Drift)
Ziel: Drift in der Befolgung der bindenden Vorgaben erkennen, ohne „KI denkt über KI nach“.
Prinzip:
	• Baseline und Checks sind deterministisch und artefaktbasiert.
	• Keine Freitext-Antworten. Nur normalisierte Felder (Enums/Strings/Listen) aus den Quellen.
Artefakte (Single-Line-JSON):
	• observer.baseline.json: Baseline (nur erneuern, wenn Spezifikation bewusst geändert wurde)
	• observer.state.json: letzter Check (last_check_ts, last_result, last_diff_keys)
Baseline-Inhalt (Beispiel-Felder, festes Schema):
	• sources_hash: Hash aus (README, Roadmap, Contract, manual.digest, env_inventory.digest)
	• answers:
		○ platform_phase1 (Enum)
		○ platform_phase2 (Enum)
		○ signals_primary (z.B. #ci)
		○ truth_order_top (Liste)
		○ git_noninteractive_prefix
		○ terminal_guard_enabled (bool)
		○ verify_standard_cmd, verify_deep_cmd
		○ verify_escalation (Enum)
Check-Zyklus:
	• Trigger: Chat-Start und alle observer_interval Iterationen (Default: 15) sowie vor Signal #ci stp.
	• Wenn observer: off: keine Checks.
Vergleichslogik:
	1. Rechne sources_hash_current aus den aktuellen Quellen/Digests.
	2. Wenn sources_hash_current != baseline.sources_hash:
		○ Ergebnis: baseline_outdated:true (Spezifikation hat sich geändert).
		○ Kein Drift-Alarm. Baseline nur durch explizite Aktion aktualisieren.
	3. Wenn sources_hash_current == baseline.sources_hash und answers_current != baseline.answers:
		○ Ergebnis: drift:true.
		○ Aktion: route_ok:false, blocked setzen, sofort Signal #ci stp ausführen.
Aktionen (Signale):
	• #ci observer-baseline: Baseline aus Quellen/Digests neu erzeugen (nur bei bewusstem Spec-Change).
	• #ci observer-check: Check jetzt ausführen und Ergebnis in observer.state.json schreiben.
10) Signal #ci stp (Scheunentorprotokoll / Sync-Checkpoint)
Zweck: Rückschreibung objektiver Fakten in Dateien, damit ein neuer Agent deterministisch fortsetzt.
Erlaubt: Fakten aus FS/Git/Commands/Logs (Hashes, Exitcodes, HEAD, Pfade, Zeitstempel).
Verboten: neue Pläne, Hypothesen, neue Architekturentscheidungen, neue To-Dos.
Prozedur:
	1. Wenn browser_tests: staged: wenn Trigger erfüllt und keine frische Smoke-Evidence existiert → #ci browser-smoke (best effort).
	2. Keine neuen Code-Änderungen.
	3. Read-only Sync-Commands: git status/head/ahead-behind, relevante tails (falls vorhanden).
	4. handoff.latest.json schreiben/aktualisieren.
	5. todo.state.json/todo.current.md konsolidieren.
	6. Optional: 1 JSONL-Event type:"stp".
	7. Antwort endet mit CAPSULE (letzte Zeile). Danach kann der Chat fortgesetzt werden (kein „Stopp“).
No-Go:
	• Keine zusätzlichen Fix-Versuche „nur weil noch Zeit ist“. #ci stp ist ausschließlich Sync/Übergabe.

11) CAPSULE (Single-Line-JSON)
Regel: letzte Zeile jeder Antwort und identisch in handoff.latest.json.
{"ts":"<ISO-8601>","agent_id":"<A-01>","workspace_root":"<ABS_PATH>","project":"<name>","active_id":"<TD-...>","status":"open|in-progress|blocked|done","goal":"<1 Satz>","changed":["path"],"verified":[{"cmd":"...","exit":0}],"route_ok":true,"route_violations":[],"git":{"branch":"...","head":"...","ahead_behind":"..."},"next":"<konkret>","refs":["todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.json"],"manual_missing":false,"env_inventory_missing":false,"env_inventory_used":true,"env_inventory_path":"env-inventory.snapshot.md"}

12) Chat-Signale (Kurzmenü)
Signalformat:
	• Signalzeilen beginnen am Zeilenanfang mit #ci .
	• Legacy-Form (<<...>>) wird erkannt, darf aber nicht in Terminal-Kommandos verwendet werden.
	Signal	Alias (Legacy)	Zweck
	#ci menu	<<menü>>	Gibt nur dieses Kurzmenü aus
	#ci stp	<<stp>>	Scheunentorprotokoll: Sync-Checkpoint (Logs/Handoff schreiben), endet mit CAPSULE
	#ci loop	<<loop>>	Loop-Intervention: höhere Warte, 1 deterministischer Schritt oder blocked+stp
	#ci bootstrap	<<cmd:bootstrap>>	Pflichtartefakte anlegen
	#ci todo-rebuild	<<cmd:todo-rebuild>>	todo.state.json aus JSONL rebuild
	#ci todo-sanitize	<<cmd:todo-sanitize>>	todo.current.md kürzen/migrieren
	#ci todo-compact	<<cmd:todo-compact>>	Abgehandelte Tasks aus Views entfernen; todo.master.index.json aktualisieren
	#ci todo-prune	<<cmd:todo-prune>>	Events erledigter To-Dos nach logs/todo/ verschieben; Digest aktualisieren
	#ci todo-rotate	<<cmd:todo-rotate>>	Aktive Event-History rotieren; todo.checkpoint.json + Digest aktualisieren
	#ci route-check	<<cmd:route-check>>	Route-Check (read-only) ausführen und Ergebnis in CAPSULE/State schreiben
	#ci git-sync	<<cmd:git-sync>>	Sync mit Upstream
	#ci patch-apply	<<cmd:patch-apply>>	Patch aus .ci/patches/ deterministisch via git apply anwenden
	#ci milestone	<<cmd:milestone>>	Milestone-Snapshot
	#ci observer-baseline	<<cmd:observer-baseline>>	Observer-Baseline erzeugen/erneuern
	#ci observer-check	<<cmd:observer-check>>	Observer-Check ausführen; observer.state.json aktualisieren
	#ci preflight	—	Preflight jetzt ausführen (7.1.1)
	#ci deps-bootstrap	—	Dependency-Bootstrap ausführen (7.0.1)
	#ci devserver-start	—	Dev-Server im Hintergrund starten (8.6)
	#ci devserver-stop	—	Dev-Server stoppen (8.6)
	#ci sonar-start	—	SonarQube Community Edition im Hintergrund starten (sonar.cmd start)
	#ci sonar-stop	—	SonarQube stoppen (sonar.cmd stop)
	#ci pyserver-start	—	Python Static Server starten (8.6.1)
	#ci pyserver-stop	—	Python Static Server stoppen (8.6.1)
	#ci browser-smoke	—	Browser-Smoke ausführen (7.1.3)

13) Chat-Ausgabeformat
Pro Iteration:
	• Changed: ...
	• Verified: ...
	• Next: ...
	• Refs: ...
	• CAPSULE (letzte Zeile)
--- 

# Addendum v3.1 (Weiterentwicklung, ohne Altes zu löschen)

## A) Projektstart aus 1 Programmanweisung (Manual entkoppelt)
- **Ziel:** Ein Projekt soll ausschließlich über **eine** Programmanweisung startbar sein.
- **Ort:** `manual/PROGRAM.md` (create-if-missing beim `#ci bootstrap`).
- **README.md:** enthält nur noch CI-Bedienung und Verweis auf `manual/PROGRAM.md` (create-if-missing).

## B) Autonomer Backlog: Roadmap → Todo-Seeding
Problem: Wenn `todo.state.json` leer ist, erstellt ein Agent häufig **keine neuen Aufgaben** und driftet.

**Regel (deterministisch):**
- Wenn `todo.state.json.items` leer ist:
  - Parse `Roadmap.md` nach Checkbox-Items `- [ ] ...`
  - Seed bis `seed_max_items` (Default: 8)
  - Schreibe `todo.state.json`, rendere `todo.current.md`, append 1 Event in `todo.events.jsonl` (type=`seed`, source=`roadmap`)

**Signal:**
- `#ci todo-seed` (manuell)
- Auto-Seed in `#ci bootstrap` (und optional `#ci start`)

## C) Self-Check als Fallback und Diagnose
- Neues Signal: `#ci self-check`
- Wird von `#ci verify` genutzt, wenn kein Build-System erkannt wird.
- Prüft Runtime-Invarianten (Existenz/Lesbarkeit von Truth-Dateien, Todo-Invarianten, Verify-Digest-Sanity).

## D) Konsolen-Output: sichtbar, ob ein Kommando erfolgreich war
Problem: zu wenig Feedback → Nutzer sieht nicht, ob ein Kommando „fertig“ ist.

**Konvention (immer):**
- Start: `[CI] BEGIN: <cmd>`
- Erfolg: `[CI] OK: <cmd> (<sec>s)` (+ optional `log: <path>`)
- Fehler: `[CI] FAIL: <cmd> (<sec>s)` + `Write-Error <msg>` (+ `log:`)

## E) Empfohlener Einstieg (für neue Chats/Agents)
- `.ci\bin\ci.cmd start`
  - beinhaltet: `bootstrap` + `preflight` + `doctor`
- Danach normal: `verify` → `route-check` → `stp`

## F) Kompatibilität
- Bestehende Aussagen/Regeln aus „Universal CI – Meisterprompt v3“ bleiben gültig.
- Addendum erweitert nur um: Manual-Entkopplung, Roadmap→Todo-Seed, Self-Check, verbesserten Konsolen-Output.



## Manual

- See: `manual\PROGRAM.md`

## Wichtiger Hinweis zu Git-Operationen
- Ein `git reset` darf **niemals** ohne explizite Genehmigung des Users durchgeführt werden. Nicht genehmigte `git reset`-Operationen können zu Datenverlust und Inkonsistenzen im Projekt führen.

## Hintergrund-Prozesse (hart)
- Alle Server (Dev-Server, SonarQube, Static-Server) MÜSSEN im Hintergrund gestartet werden.
- Vordergrund-Starts, die das Terminal blockieren, sind verboten.
- Nutze die entsprechenden Signale (#ci devserver-start, #ci sonar-start).

## Git & Terminal (hart)
- Alle Git-Kommandos MÜSSEN non-interactive sein (siehe 7.3).
- Pager und interaktive Prompts sind zu deaktivieren.
- Verwende für Git-Operationen immer: `git -c core.pager=cat -c color.ui=false --no-pager <cmd>`

## Umgang mit KI Anfragen. Wenn Anfragen an die KI gestellt werden, gestalte sie so, das API Anfragengrenzen nicht überschritten werden.

## Mache bei jedem Milestone einen Gradle, Browser und Funktionstest und wenn ok, dann Git Commit

##Testpflicht pro Funktion (Definition of Done)
Für jede neu erstellte, bereits bestehende oder geänderte Funktion muss im selben Commit eine zugehörige Testfunktion/Testdatei erstellt werden, die die Funktion vollständig abdeckt:

Values/Validierung: typische Werte, Grenzwerte, ungültige Eingaben, Fehlermeldungen/Exceptions

Logikpfade: alle Branches (if/else), Sonderfälle, leere/null Inputs, Idempotenz (wenn relevant)

Nebenwirkungen/Integrationen: I/O, DB/API/FS (mit Mocks/Stubs), State-Änderungen

Visual/UI (falls vorhanden): Rendering, Zustände, Interaktionen, Snapshots/Visual-Checks, Position, Größe, Layout

Bei jedem Test oder jedem Roadmap-Punkt sind zusätzlich visuelle Aspekte zu prüfen. Konkret: Button-Größen und Abstände, Text-Layout (kein Überlaufen), harmonische Proportionen. Test gilt erst als bestanden, wenn auch Design-Kriterien durch ein automatisiertes Review abgehakt sind.

Qualitätskriterien: reproduzierbar, deterministisch, keine Flakes, klare Assertions

Wenn andere Testmöglichkeiten bestehen oder bessere Parameter exisiteren, mit denen man eine Layoutbox genau zu beschreiben, ist dies durchzuführen.

Abdeckung: Ziel ≥ 90% Lines/Branches, keine ungetesteten Codepfade ohne Begründung

Wenn kein sinnvoller Test möglich ist, muss das begründet werden (Kommentar) und eine Alternative (Refactor für Testbarkeit, Contract-Test, Integrationstest) umgesetzt werden.

Füge alle einzelnen Funktionstest in einen "Supertest" zusammen, den ich auch mit diesem Stichwort starten kann und der dann alle Funktionen testet.

## Automatisierte Inhalts- und UI-Review (hart)

- Human-Review ist kein Release-Gate. Nutzer oder externe Reviewer muessen weder einzelne Fragen noch Stichproben aus grossen Fragebestaenden manuell freigeben.
- Inhaltsreview wird exhaustiv durch Codex-Automation ausgefuehrt. Fuer jeden reviewpflichtigen eindeutigen Kandidaten werden Identitaet, Source-/Proof-/Lizenzbindung, Antwortbarkeit, alle acht Locale-Renditions, redaktionelle Textintegritaet, Response-Vertrag und die Eindeutigkeit sichtbarer Optionen fail-closed geprueft.
- Jede Freigabe muss in einem digestgebundenen JSONL-Review-Ledger mit Policyversion, Reviewer-ID `codex`, Pruefergebnissen, Candidate-Evidence-Digest und versiegelter Zusammenfassung liegen. Eine pauschale Freigabe ohne Einzelrecord-Evidence ist verboten.
- Visuelle Review erfolgt durch einen lokalen oder Staging-Deploy ueber `cmd /c .\ci.cmd devserver-start` auf Port `8200` und automatisierte Browserlaeufe. Pflichtbelege sind SHA-256-gebundene Screenshots fuer 1920x1080, 1366x900 und 800x1280 unter `output/playwright/`; kein Nutzer muss die Screenshots manuell abnehmen.
- Ein fehlgeschlagenes Inhalts-, Layout-, Accessibility-, Browser- oder Screenshot-Gate bleibt ein echter Blocker und wird durch einen gezielten Funktionsfix beseitigt. Produktionsdeploy und Defaultswitch bleiben davon getrennte, explizit zu autorisierende Schreiboperationen.


Prüfe, ob SonarQube Server auf :9000 läuft. Wenn nich, starte ihn und lasse ihn laufen.

PowerShell (bevorzugt, Windows):
- Start: `sonar.cmd start` (nutzt `start_sonar.ps1`).
- Status: `curl http://localhost:9000/api/system/status`
- Wenn `http://localhost:9000` im Browser `ERR_CONNECTION_REFUSED` zeigt, Portproxy setzen.
- WSL-IP ermitteln: `wsl.exe -d Ubuntu-22.04 -- sh -lc "hostname -I | awk '{print $1}'"`
- Portproxy setzen: `netsh interface portproxy add v4tov4 listenport=9000 listenaddress=127.0.0.1 connectport=9000 connectaddress=<WSL-IP>`
- Portproxy prüfen: `netsh interface portproxy show v4tov4`
- Firewall (optional): `netsh advfirewall firewall add rule name="WSL SonarQube 9000" dir=in action=allow protocol=TCP localport=9000`


WSL-Reinstall (funktioniert zuverlässig):
- Zip nach `.sonarqube/dist/` entpacken (Ordner `sonarqube-26.1.0.118079` bleibt erhalten).
- `sonar.path.data=/home/sonar/.sonarqube/data`, `sonar.path.logs=/home/sonar/.sonarqube/logs`, `sonar.path.temp=/home/sonar/.sonarqube/temp` in `.sonarqube/dist/sonarqube-26.1.0.118079/conf/sonar.properties` setzen (fix fuer `elasticsearch.keystore.tmp: Operation not permitted` auf `/mnt/d`).
- Ordner anlegen + Besitz setzen: `sudo mkdir -p /home/sonar/.sonarqube/{data,logs,temp} && sudo chown -R sonar:sonar /home/sonar/.sonarqube`.
- Start (WSL): `su -s /bin/bash sonar -c ".sonarqube/dist/sonarqube-26.1.0.118079/bin/linux-x86-64/sonar.sh start"`.
- Status pruefen: `curl -s http://localhost:9000/api/system/status`.

Env: SONAR_HOST_URL, SONAR_TOKEN
Beispiel (WSL):
  SONAR_HOST_URL=http://172.24.16.1:9000 SONAR_TOKEN=<SONAR_TOKEN> ./gradlew sonar --console=plain -Dsonar.gradle.skipCompile=true
Beispiel (PowerShell):
  $env:SONAR_HOST_URL="http://localhost:9000"; $env:SONAR_TOKEN="<SONAR_TOKEN>"; .\gradlew sonar --console=plain -Dsonar.gradle.skipCompile=true

Benutze für Zufriff nur SonarQube API oder Curl.

Prüfe, ob Dev Server auf:8090 läuft. Wenn nicht, starte ihn und lasse ihn laufen.

###
Pfad Android SDK: C:\Users\ralph\AppData\Local\Android\Sdk


#########

## Roadmap-Punkte erstellen (chat-/agent-uebergreifend, hart)
Ziel: Neue Roadmap-Items muessen ohne Rueckfragen, deterministisch und im bestehenden `Roadmap.md`-Stil erzeugt werden. Jeder Punkt ist so zu schreiben, dass ein neuer Chat/Agent ihn sofort ausfuehren kann.

### Screenshot-Bindung fuer Roadmap-Punkte (hart)
- Wenn der Nutzer beim Anfordern oder Nachschaerfen eines Roadmap-Punkts Screenshots mitliefert, muessen diese Screenshots unter `doc/roadmap-screenshots/` gespeichert werden. Ordner bei Bedarf anlegen.
- Dateiname immer mit Roadmap-ID beginnen, z.B. `QA-101-openai-seed-runner-current-1589x984.png`. Keine generischen Namen wie `screenshot1.png`.
- Jeder offene Roadmap-Punkt mit Screenshot-Bezug muss einen eigenen Unterpunkt `Screenshot-Referenz:` enthalten, der konkrete Pfade unter `doc/roadmap-screenshots/` auffuehrt und in 1-2 Saetzen beschreibt, welches Fehlerbild daran bindend ist.
- Diese Screenshot-Referenzen gehoeren waehrend der gesamten Laufzeit des Punkts zu den Pflicht-Eingaben: Jeder Folgechat liest sie erneut zusammen mit `Roadmap.md`, bevor am Punkt weitergearbeitet wird.
- Beim Abschluss wird der Punkt vollstaendig nach `Roadmap_archive.md` verschoben; die `Screenshot-Referenz:`-Pfade bleiben unveraendert im archivierten Punkt stehen. Screenshots werden nicht aus `doc/roadmap-screenshots/` geloescht, solange der Archivpunkt als Referenz dienen kann.
- Wenn spaeter weitere Nutzer-Screenshots zum selben Punkt kommen, werden sie demselben Punkt unter derselben `Screenshot-Referenz:`-Sektion hinzugefuegt statt den frueheren Pfad zu ersetzen.

### Pflichtstruktur je Roadmap-Punkt (Format-Contract)
- Hauptzeile (Checkbox):
  - `- [ ] <ID> <Titel> #comment: <1 Satz Kontext/Ziel>`
  - ID: Bereich-Prefix + laufende Nummer (z.B. UI-045). Keine Duplikate.
- Unterpunkte (alle checkboxbar, eingerueckt):
  1. `Beschreibung:` Was genau soll am Ende anders sein (messbar, keine Adjektive ohne Kriterium).
  2. `Scope:` Betroffene Dateien/Module/Tests (Pfad/Dateinamen), explizite No-Gos (was NICHT aendern).
  3. `Ist-Stand (YYYY-MM-DD HH:MM):` Beobachtung + betroffene Tests/Fehler (wenn unbekannt: als TODO markieren, nicht erfinden).
  4. `Screenshot-Referenz:` Pflicht, sobald der Punkt auf Nutzer- oder Audit-Screenshots basiert; konkrete Pfade unter `doc/roadmap-screenshots/` + kurzer Bindungssatz, was genau daran zu lesen ist.
  5. `Schritte:` Nummerierte Liste mit **mindestens 3** konkreten Umsetzungsschritten (je Schritt: Aktion + betroffene Datei/Komponente + erwartetes Ergebnis).
  6. `Evidence:` Welche Artefakte am Ende existieren muessen (Screens/Logs/Pfade, Dateiname mit ID).
  7. `Funktionstest:` Exakte Commands/Tests (z.B. `node tests/ui/<...>.js`).
  8. `Audit:` Automatisierter Browser-/Visual-Check nach lokalem oder Staging-Deploy (mind. 1920/1366/800) mit Screenshot-Digests und klaren Akzeptanzkriterien (kein Overlap/Clipping, Touch-Targets, Typo); keine Human-Abnahme.
  9. `Supertest:` Abschlusslauf (i.d.R. `node tests/ui/run-supertest.js`) erst nach gruenen Funktionstests.

No-Go: Keine vagen Punkte wie "optimieren" ohne Metrik; keine erfundenen Dateipfade/Fehler; kein Android-spezifischer Code in Phase 1 (siehe Plattformstrategie).

### Prompt-Template (copy/paste)
Verwende dieses Template als EINEN Prompt an den Agenten:

```
Erstelle <N> neue Roadmap-Punkte im exakten Stil der bestehenden Roadmap.md.

Harte Regeln:
- Ausgabe NUR als Markdown-Roadmap-Items (Checkboxen), keine Erklaertexte.
- Pro Hauptpunkt: Hauptzeile mit `#comment:` + Unterpunkte in dieser Reihenfolge:
  Beschreibung, Scope, Ist-Stand (YYYY-MM-DD HH:MM), Screenshot-Referenz (wenn screenshotgebunden), Schritte (min. 3, nummeriert), Evidence, Funktionstest, Audit, Supertest.
- Jeder Unterpunkt ist checkboxbar und enthaltene Anforderungen sind messbar.
- Keine erfundenen Facts: Wenn ein Detail unbekannt ist, schreibe `TODO: <was zu ermitteln ist>`.
- Platform/CI-Guardrails einhalten (Web/PWA only, keine android.* / androidx.* Imports).
- Wenn der Nutzer Screenshots mitliefert: unter `doc/roadmap-screenshots/` speichern, in `Screenshot-Referenz:` auffuehren und bis zum Archivpunkt unveraendert mitfuehren.

Themen/Intent fuer die neuen Punkte:
1) <Thema 1, 1 Satz Ziel>
2) <Thema 2, 1 Satz Ziel>
...

Kontext (bindend): Roadmap.md als Source of Truth fuer Stil, Tests und Dateinamen.
```

### Output-Selbstcheck (Agent muss vor Abgabe erfuellen)
- [ ] Jeder Punkt hat `#comment:` (1 Satz, laesst keinen Interpretationsspielraum).
- [ ] Bei screenshotgebundenen Punkten existiert `Screenshot-Referenz:` mit konkreten Pfaden unter `doc/roadmap-screenshots/`; diese Pfade bleiben bis zum Archivpunkt erhalten.
- [ ] `Schritte` hat >= 3 Schritte; jeder Schritt nennt Aktion + Datei/Komponente + erwartetes Resultat.
- [ ] `Evidence` nennt konkrete Pfade/Dateinamen mit ID.
- [ ] `Funktionstest` listet konkrete Commands (keine "Tests laufen lassen").
- [ ] `Audit` und `Supertest` sind IMMER vorhanden und am Ende.
- [ ] Keine neuen Architekturentscheidungen; kein Drift gegen README/Roadmap-Guardrails.

## Standard-Themenkatalog fuer Quizfragen
- Verbindliche Kategorien:
  - `MINT` (Mathematik, Informatik, Naturwissenschaften, Technik als Sammelbereich)
  - `Geschichte & Politik`
  - `Geografie`
  - `Kultur & Medien`
  - `Sport`
  - `Alltag & Gesellschaft`
- Fuer neue Fragen muss immer genau eine Kategorie aus dem Katalog gesetzt sein.
- Legacy-Datensaetze ohne Kategorie bleiben bis zur vollstaendigen Nachmigration lesbar, duerfen aber nicht als neuer Standard erzeugt werden.
