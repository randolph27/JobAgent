# Kontrollierte Migration

Die folgenden Schritte sind absichtlich getrennt. `Plan` und `Audit` sind read-only; `Install`, `Update` und `Repair` schreiben in das Zielprojekt.

## 1. Ausgangszustand sichern

Vor der ersten Installation:

```powershell
git -C "D:\_Scripte\Chess" status --short
D:\_Scripte\Bootstrap\bootstrap.cmd Audit -CompareSources
D:\_Scripte\Bootstrap\bootstrap.cmd Plan -TargetRoot "D:\_Scripte\Chess" -Profile chess
```

Plan prüfen auf:

- `replace`-Einträge unter `.ci/bin`;
- `config = preserve-mutable`;
- `legacy_pin_migration.readonly_mutable_files`;
- unerwartete Reparse Points oder ungültige Legacy-Pfade.

## 2. Installation

```powershell
D:\_Scripte\Bootstrap\bootstrap.cmd Install -TargetRoot "D:\_Scripte\Chess" -Profile chess
```

Bei absichtlich abweichenden Runtime-Dateien erst Diff prüfen, dann explizit:

```powershell
D:\_Scripte\Bootstrap\bootstrap.cmd Install -TargetRoot "D:\_Scripte\Chess" -Profile chess -Force
```

Wirkung:

- zentrale Runtime und Profilpayload werden installiert;
- vorhandene Konfiguration bleibt erhalten;
- alte Pin-Metadaten werden in das Bootstrap-Backup kopiert;
- ReadOnly wird nur bei bekannten, im alten Pin-Manifest enthaltenen mutablen Dateien gelöst;
- alte Pin-/Snapshot-Dateien bleiben am Ort und werden nicht blind gelöscht;
- Projektbindung und Runtime-Manifest werden erzeugt.

## 3. Abnahme

```powershell
cd D:\_Scripte\Chess
.\ci.cmd bootstrap-verify
.\ci.cmd self-check
D:\_Scripte\Bootstrap\bootstrap.cmd Audit -TargetRoot "D:\_Scripte\Chess"
```

Danach einen ungefährlichen projektspezifischen Diagnosebefehl ausführen, beispielsweise `doctor` oder `env-inventory`. Build-, Sonar- und Browserbefehle erst nach erfolgreicher Diagnose.

## 4. Reihenfolge der drei Projekte

Empfohlen:

1. Sound Profile: kleinste Commandmenge und wenigste Roadmap-Fehler, aber Android-/Sonar-Umgebung beachten.
2. Ubuntu Web: mittlere Runtime, zusätzliche Seed-/Release-Funktionen und ein bekannter Handoff-Widerspruch.
3. Chess: größte Runtime und Historie, zusätzliche Android-/Viewport-/Git-ACL-Funktionen sowie stärkste Todo-Formatdrift.

Zwischen den Projekten mindestens einen vollständigen Arbeitszyklus beobachten. Die Reihenfolge ist eine Risikoreduktion, keine technische Abhängigkeit.

## 5. Rückweg

`Repair` stellt den zentralen Sollstand wieder her. Für einen vollständigen Rückbau existiert bewusst kein automatisches Löschkommando, weil alte und neue Dateien nicht zweifelsfrei getrennt werden können. Die transaktionsbezogenen Backups unter `Bootstrap\backups\<project-id>\...` enthalten ersetzte Dateien und Metadaten. Ein Rückbau erfolgt erst nach manueller Diff-Prüfung.

## Nicht Teil der Runtime-Migration

Todo-, Roadmap- und Handoff-Inhalte werden nicht automatisch umgeschrieben. Ihre Datenmigration folgt dem gesonderten Workflow-V2-Verfahren.

