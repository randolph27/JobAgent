# Analyse der drei Workflow-Bestände

Stand: 2026-08-02, letzte read-only Erfassung gegen 20:24 Uhr Europe/Berlin. Die Bestände werden parallel weiterentwickelt; deshalb sind Todo-, Roadmap- und Audit-Zahlen eine Momentaufnahme. Aufwands- und Dauerschätzungen sind ausdrücklich als Schätzung markiert.

## Zusammenfassung

Eine einzige zusammengeführte `ci.ps1` wäre riskant: zahlreiche Funktionsnamen besitzen profilabhängig unterschiedliche Implementierungen. Deshalb verwendet der Bootstrap drei vollständige Profile, bytegenaue Referenz-Templates und einen kleinen gemeinsamen Loader. Es wurden keine historischen Commands oder Funktionen entfernt.

| Bestand | Ubuntu Web | Chess | Sound Profile |
|---|---:|---:|---:|
| PowerShell-Definitionen | 305 | 328 | 292 |
| eindeutige Funktionen | 291 | 314 | 278 |
| Commands | 63 | 67 | 59 |
| Todo-Eventobjekte | 43 | 115 | 4 |
| Todo-Eventdatei | 33.184 B | 59.543 B | 2.591 B |
| aktive Roadmap-IDs | 10 | 0 im unterstützten Format | 4 |
| archivierte Roadmap-IDs | 815 | 1.599 | 452 |
| Auditfehler / Warnungen | 15 / 2 | 20 / 12 | 0 / 0 |

## README

| Merkmal | Ubuntu Web | Chess | Sound Profile |
|---|---:|---:|---:|
| Zeilen | 1.053 | 1.037 | 991 |
| Größe | 66.784 B | 66.865 B | 62.437 B |
| H1 / H2 | 13 / 20 | 12 / 16 | 12 / 18 |
| Code-Fences | 3 | 3 | 10 |
| längste Zeile | 554 Zeichen | 554 Zeichen | 554 Zeichen |

Befunde:

- Ubuntu und Chess haben eine ungerade Fence-Anzahl. Markdown nach der offenen Fence kann falsch gerendert oder als Code interpretiert werden.
- Shell-/PowerShell-Kommentare aus eingebetteten Skripten werden teilweise als H1 interpretiert. Die Dokumenthierarchie bildet dadurch nicht zuverlässig die fachliche Struktur ab.
- Betriebsvertrag, Agentenregeln, eingebettete Skripte, Projektstart und Historie liegen in einem Dokument. Das ist umfassend, erschwert aber Review, Diff und eindeutige Zuständigkeit.
- Die Verbesserung sollte Inhalte auslagern und verlinken, nicht löschen: `README.md` als Einstieg, `docs/WORKFLOW.md` für Regeln, echte `.ps1` für ausführbaren Code und generierte Command-Referenz aus dem Katalog.

## CI-Skripte

Stärken, die erhalten wurden:

- breite Diagnose-, Toolchain-, Observer-, Todo-, Sonar-, UI- und Recovery-Funktionen;
- projektbezogene Spezialisierung statt eines zu kleinen gemeinsamen Nenners;
- vorhandene Lock-, Logging-, Retry-, Handoff- und Evidence-Konzepte;
- umfangreiche Commandregistrierung einschließlich Kurzbefehlen.

Kritische Befunde und Bootstrap-Antwort:

| Befund | Wirkung | Umsetzung im Bootstrap |
|---|---|---|
| Chess/Sound luden Module vor einer belastbaren Integritätsentscheidung | manipulierte Runtime könnte vor Prüfung laufen | zentrale Release-Prüfung vor Child-Start; erneute Prüfung nach Child-Ende |
| lokale Pins enthielten mutable Dokumente | README/Roadmap/Config wurden schreibgeschützt und konnten veralten | zentral verwaltete Runtime; kontrollierte ReadOnly-Migration nur für bekannte mutable Pfade |
| lokale Repin-/Restore-Commands konnten die Vertrauensbasis selbst ändern | zirkuläre Autorität | historische Namen bleiben als zentrale `Repair`-/`Update`-Kompatibilitätsaufrufe erhalten; exakte lokale Semantik nur im Referenzmodus |
| Event-/Tick-Argumente gingen in Ubuntu/Sound im Scriptblock verloren | Optionen wie `-f` wirkten nicht zuverlässig | persistenter Dispatcher-Argumentkontext |
| Gradle-SHA-Fehler wurden in Ubuntu/Sound nur gewarnt | ungeprüftes Archiv konnte weiterverwendet werden | Cache und Download sind fail-closed SHA-256-geprüft; verifizierte Sidecars erhalten Offline-Nutzung |
| Chess Sonar-Helper enthielt absoluten Projektpfad | keine portable Installation | Auflösung relativ zum installierten Repository |
| Sound enthielt einen benutzerspezifischen Android-SDK-Pfad | anderer Benutzer/Host scheitert | Ableitung aus `LocalApplicationData` |
| UI-Funktionen waren doppelt; `Ui-TryWebBuild` widersprach sich | zuletzt geladener Body bestimmte zufällig die Taskfolge | beide Definitionen bewusst erhalten und semantisch angeglichen |
| Self-Check erwartete im zentralen Modus abgeschaffte Pins | frische Installation wäre dauerhaft rot | zentraler Integritätsstatus ersetzt nur in `CI_BOOTSTRAP_PREVERIFIED=1` die Pinprüfung |

Verbleibende Portabilitätsaltlasten sind der Ubuntu-Standardpfad für den OpenAI-Key und feste Git-LFS-Standardverzeichnisse. `OPENAI_API_KEY_FILE` überschreibt den Keypfad; Git LFS sollte in einem Folge-Release über `Get-Command git-lfs` ermittelt werden.

## Todo-Historie

Gemeinsame Befunde:

- Ubuntu und Chess besitzen noch ein duales Master-Schema (`items` und `todos` gleichzeitig); eine automatische Auswahl einer Seite wäre Datenverlust.
- Der Audit muss ISO-Zeitstempel kulturunabhängig mit `InvariantCulture` und `RoundtripKind` lesen. Diese Bootstrap-Korrektur verhindert die frühere Fehlinterpretation `2026-08-02` als 8. Februar.
- Eine durchgehende kryptografische Hashkette zwischen aktiver Eventdatei, Checkpoint und allen historischen Archiven ist nicht nachgewiesen.

Profilspezifisch:

- Ubuntu: `items` und `todos` sind gleichzeitig gefüllt (83/188), eine JSONL-Leerzeile ist vorhanden und die Eventdatei überschreitet die dokumentierte Bytegrenze.
- Chess: duales Master-Schema (32/6), acht Events ohne `event_id`; Linien-, Byte- und Altersgrenze sind überschritten.
- Sound: Rotation, History-Digest, eingebetteter Checkpoint-v2-Zustand und `checkpoint_event_id` sind inzwischen vorhanden. Der aktualisierte read-only Audit meldet dafür aktuell 0 Fehler und 0 Warnungen.

Eine automatische Rekonstruktion der Ubuntu-/Chess-Altbestände wäre spekulativ. Unterschiedliche Schemas und fehlende Event-IDs erlauben keine beweisbare chronologische Wahrheit. Der Bootstrap führt daher zunächst nur ein Audit aus; Sound dient als erprobte Vorlage, nicht als ungeprüfter Migrationsautomatismus.

## Roadmap und Historie

- Ubuntu: 13 IDs sind im Archiv doppelt; `QF-009` erscheint dreimal. Aktive und archivierte Inhalte benötigen einen eindeutigen Primärschlüssel und eine kontrollierte Deduplizierungsentscheidung.
- Chess: 18 archivierte IDs sind doppelt. Der aktuelle `Roadmap.md` liefert keine aktiven Einträge im vom bestehenden Parser erwarteten Checkbox-/ID-Format; dies ist Formatdrift, nicht automatisch „keine Arbeit“.
- Sound: Der Audit fand keine doppelten Roadmap-IDs. Der aktuelle Parser erkennt 4 aktive und 452 archivierte IDs; Todo-/Checkpoint-v2 ist derzeit konsistent.

Empfehlung: Roadmap bleibt menschenlesbare Planung, Todo-State bleibt maschinenlesbarer Zustand. IDs werden einmalig vergeben; Archive sind immutable Generationen statt wiederholt angehängter Textblöcke.

## Priorisierte Verbesserungen

Annahme für die Schätzung: eine Person, etwa 6 produktive Stunden pro Arbeitstag, keine parallelen Schreibprozesse während einer späteren Migration. Projektgröße und gewünschter Zeithorizont wurden nicht vorgegeben. Prioritätsscore 0–100 gewichtet Abhängigkeiten, kritischen Pfad, Risiko, Nutzen und Aufwand; er ist eine Planungsheuristik, keine Messung.

| Rang | Punkt | Abhängigkeiten | Aufwand / Dauer (Schätzung) | Score | Ordnungsbegründung | Risiken | Meilenstein |
|---:|---|---|---|---:|---|---|---|
| 1 | Verlustfreie Baseline: Referenz-Templates, vollständige Profile, Funktionskörper-/Topologie-/Commandtests | keine | 1–2 PT / 1–2 Tage | 99 | Jede weitere Änderung braucht zuerst einen beweisbaren Nullverlust-Vertrag | parallel veränderte Quellen erzeugen Drift; lokale Änderungen müssen explizit erfasst werden | M1 – Bestand gesichert |
| 2 | Zentrale Integrität und Recovery-Kompatibilität mit Vor-/Nachprüfung, Repair/Update-Mapping und Legacy-Fallback | Rang 1 | 1–2 PT / 1–3 Tage | 96 | Liegt auf dem kritischen Ausführungspfad und verhindert Selbst-Pinning manipulierter Runtime | zentraler Pfad ist ohne ACL/Signatur noch kein externer Vertrauensanker | M1 – Bestand gesichert |
| 3 | README-Vertrag vollständig halten, offene Fences korrigieren und ausführbaren Code nur additiv in echte Skripte überführen | Rang 1; fachlicher Review je Profil | 0,5–1 PT je Projekt / 1–3 Tage, parallelisierbar | 88 | Dokumentfehler beeinflussen Bedienung; fachliche Inhalte dürfen dabei nicht verschwinden | Auslagerung ohne Link-/Vollständigkeitstest könnte erneut kürzen | M1 – Bestand gesichert |
| 4 | Ubuntu und Chess auf einen geprüften Todo-/Checkpoint-v2-Vertrag migrieren; Sound-Mechanik als Referenz verwenden | Ränge 1–2; vollständiges Backup; Entscheidung `items` versus `todos` | 2–4 PT je Projekt / 3–6 Tage, zwischen Projekten parallelisierbar | 84 | Behebt die größten verbliebenen Zustands- und Recovery-Risiken | unklare chronologische Wahrheit, fehlende Event-IDs, mögliche Doppelzählung | M2 – Workflow-Daten konsistent |
| 5 | Roadmap-IDs deduplizieren und Chess-Formatdrift mit expliziter Mappingentscheidung beheben | Rang 1; Eigentümerentscheidung für Duplikate und Primärdatensatz | 1–3 PT je Projekt / 2–5 Tage, teilweise parallelisierbar | 76 | Erst nach gesicherter Baseline dürfen IDs zusammengeführt oder neu zugeordnet werden | falsche Deduplizierung kann Historie oder Referenzen brechen | M2 – Workflow-Daten konsistent |
| 6 | Release-Vertrauen mit restriktiver ACL, optionaler Signatur und dokumentierter Backup-Retention härten | Ränge 1–2 | 2–5 PT / 3–7 Tage | 71 | Erhöht Sicherheitsniveau nach funktionaler Stabilisierung | Zertifikats-/Schlüsselbetrieb und ACL-Rollout benötigen Betriebsentscheidungen | M3 – Betrieb gehärtet |

M1 ist im Bootstrap umgesetzt; Änderungen an den drei Quellprojekten wurden bewusst nicht ausgeführt. M2 und M3 sind Vorschläge und benötigen einen gesonderten Schreibauftrag sowie die genannten fachlichen Entscheidungen.
