# Workflow Bootstrap

Zentraler, profilbasierter Bootstrap für die vorhandenen CI-Workflows von Ubuntu VPS Quiz Web, Chess und Sound Profile. Release `1.0.0` bewahrt alle statisch definierten Funktionen und Commands der drei Quellen; projektabhängige Implementierungen bleiben getrennt.

Der Bootstrap ist erstellt, aber nicht in die drei Quellprojekte installiert. Die Quellen wurden nur gelesen. Eine Installation ist eine gesonderte, schreibende Aktion.

## Voraussetzungen

- Windows mit PowerShell 7.4 oder neuer
- Git für den Provenienz- und Kompatibilitätstest
- Zentraler Pfad `D:\_Scripte\Bootstrap`

Es wird kein `ExecutionPolicy Bypass` verwendet. Das Release-Manifest erkennt Drift, ist ohne gehärtete ACL oder Signatur aber kein externer Vertrauensanker.

## Profile und Funktionsvertrag

| Profil | Quelle | Definitionen | eindeutige Funktionen | Commands |
|---|---|---:|---:|---:|
| `ubuntu-web` | `D:\_Scripte\UbuntuVPS_Quiz\web` | 305 | 291 | 63 |
| `chess` | `D:\_Scripte\Chess` | 328 | 314 | 67 |
| `sound-profile` | `D:\_Scripte\Sound Profile` | 292 | 278 | 59 |

Die Vereinigungsmenge umfasst 487 Funktionen und 76 Commands. Der Vertrag prüft nicht nur Namen, sondern auch Definitionshäufigkeit, Quelldateizuordnung, Parameterfolge und AST-Elternstruktur. Dadurch werden versehentlich verschachtelte oder verlorene Funktionen erkannt.

## Zentrale Bedienung

Nur lesen:

```powershell
D:\_Scripte\Bootstrap\bootstrap.cmd List
D:\_Scripte\Bootstrap\bootstrap.cmd Audit -CompareSources
D:\_Scripte\Bootstrap\bootstrap.cmd Plan -TargetRoot "D:\_Scripte\Chess" -Profile chess
```

Installation nach Prüfung des Plans:

```powershell
D:\_Scripte\Bootstrap\bootstrap.cmd Install -TargetRoot "D:\_Scripte\Chess" -Profile chess
```

`Install` erhält eine vorhandene `.ci\ci.config.json`. Nur `-ReplaceConfig` ersetzt sie ausdrücklich. Abweichende vorhandene Runtime-Dateien verlangen bei der Erstinstallation `-Force`.

Nach der Installation wird das bekannte Projektkommando weiterverwendet. Ein dedizierter Raw-Argument-Launcher verhindert, dass Legacy-Schalter als Bootstrap-Parameter gebunden werden:

```powershell
cd D:\_Scripte\Chess
.\ci.cmd self-check
.\ci.cmd tick -f
.\ci.cmd bootstrap-verify
.\ci.cmd workflow-audit --json
```

Beim direkten zentralen Aufruf übernimmt `run.cmd` die unveränderten Legacy-Argumente:

```powershell
D:\_Scripte\Bootstrap\run.cmd "D:\_Scripte\Chess" tick -f
```

Der installierte `ci.cmd` verwendet denselben Raw-Launcher automatisch. Manuelle Aufrufe von `bootstrap.cmd Run` oder `Bootstrap.ps1 Run` sind nicht unterstuetzt; `Run` ist nur die bereits typisiert aufgerufene interne Managerfunktion.

## Update und Reparatur

```powershell
D:\_Scripte\Bootstrap\bootstrap.cmd Audit -TargetRoot "D:\_Scripte\Chess"
D:\_Scripte\Bootstrap\bootstrap.cmd Repair -TargetRoot "D:\_Scripte\Chess"
D:\_Scripte\Bootstrap\bootstrap.cmd Update -TargetRoot "D:\_Scripte\Chess"
```

- `Repair` stellt ausschließlich das gebundene Profil wieder her.
- `Update` verlangt eine bestehende Bindung. Ein Profilwechsel verlangt `Update -Profile <id> -Force`.
- Die historischen Aufrufe bleiben über `ci.cmd` nutzbar: `restore-immutables` und `repin-immutables` führen im verwalteten Modus ein zentrales `Repair` aus; `runtime-update` führt ein zentrales `Update` aus.
- Die bytegenauen Referenz-Templates behalten zusätzlich die ursprüngliche lokale Pin-/Snapshot-Semantik. Im verwalteten Modus bleibt das zentrale Release die Vertrauensbasis.
- Jede Publikation nutzt Staging, Hashprüfung, Projekt-Lock, Backups und best-effort Rollback.
- Unerwartete Skripte werden nicht automatisch gelöscht; Audit meldet sie zur manuellen Prüfung.

## Legacy-Pins

Die drei Quellen besitzen alte `.ci\pins\immutable.hashes.json` und schreibgeschützte mutable Dokumente. `Plan` zeigt die betroffenen Dateien. Bei einer späteren Installation wird das Pin-Manifest in das Transaktionsbackup kopiert und `ReadOnly` nur für containment-geprüfte, bekannte mutable Dateien gelöst. Das alte Pin-Manifest wird nicht gelöscht.

## Tests

```powershell
pwsh -NoProfile -File D:\_Scripte\Bootstrap\tests\Test-Compatibility.ps1
pwsh -NoProfile -File D:\_Scripte\Bootstrap\tests\Test-ReferenceTemplates.ps1
powershell.exe -NoProfile -File D:\_Scripte\Bootstrap\tests\Test-LegacyPowerShell.ps1
pwsh -NoProfile -File D:\_Scripte\Bootstrap\tests\Test-Bootstrap.ps1
```

`Test-Bootstrap.ps1` prüft Syntax, JSON, Release-Closure, Profile, Quellenvergleich sowie Install/Audit/Tamper/Repair in eindeutigen temporären Verzeichnissen. Die drei Quellen werden vor und nach dem Lauf per Hash, Attribut und Git-Status verglichen.

## Dokumentation

- `docs/ANALYSE.md`: Befunde aus README, CI, Roadmap und Todo-Historie
- `docs/ARCHITEKTUR.md`: Vertrauens- und Installationsmodell
- `docs/MIGRATION.md`: kontrollierte Einführung in die drei Projekte
- `docs/WORKFLOW-V2.md`: Zielmodell für eine verlustfreie Historienmigration
- `docs/SECURITY.md`: Grenzen des Integritätsschutzes
- `docs/ROADMAP.md`: priorisierte Weiterentwicklung
