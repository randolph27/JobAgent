# Architektur

## Prinzip

Der gemeinsame Teil verwaltet Vertrauen, Installation, Audit und Transaktionen. Die fachliche CI-Logik bleibt in drei vollständigen Profilpaketen. Damit werden Unterschiede sichtbar versioniert statt durch eine große Menge bedingter Verzweigungen verdeckt.

```text
Bootstrap 1.0.0
├─ Bootstrap.ps1              zentrale Autorität
├─ bootstrap.manifest.json    Hash-/Größen-Closure
├─ runtime/                   Loader, Launcher, Workflow-Audit
├─ profiles/
│  ├─ ubuntu-web/             vollständige Legacy-Funktionalität + gezielte Korrekturen
│  ├─ chess/
│  └─ sound-profile/
├─ catalog/                   Vereinigungs- und Divergenzkatalog
├─ schemas/                   Runtime- und Workflow-Verträge
└─ tests/                     Kompatibilitäts- und Lebenszyklusverträge
```

## Installierter Aufbau

```text
<Projekt>/
├─ ci.cmd
└─ .ci/
   ├─ ci.config.json                 mutable, standardmäßig erhalten
   ├─ bin/                           vollständig zentral verwaltet
   │  ├─ ci.cmd
   │  ├─ ci.ps1
   │  ├─ legacy-ci.ps1
   │  └─ modules/...
   ├─ tools/observer-daemon.ps1
   └─ bootstrap/
      ├─ runtime.manifest.json
      ├─ catalog/...
      ├─ modules/workflow-audit.ps1
      └─ schemas/...
```

## Ausführung

1. Projekt-`ci.cmd` delegiert über `run.cmd`/`Run.ps1`; der parameterlose Raw-Launcher übernimmt auch kollidierende Legacy-Schalter unverändert.
2. Der Manager prüft die komplette zentrale Release-Closure.
3. Die zentrale Projektbindung bestimmt Profil und Version.
4. Alle installierten Dateien sowie das Zielmanifest werden gegen die zentrale Erwartung geprüft.
5. Ein exklusiver Projekt-Lock wird gehalten.
6. Ein separates PowerShell-7.4-Kind startet im Projektarbeitsverzeichnis den installierten Loader.
7. Der Loader prüft das lokale Manifest als zusätzliche Schicht und delegiert an `legacy-ci.ps1`.
8. Nach Ende des Child-Prozesses prüft der Manager die Runtime erneut.

`CI_BOOTSTRAP_PREVERIFIED=1` ist nur ein vom zentralen Elternprozess gesetzter Kompatibilitätsmodus. Das Flag allein ist kein Vertrauensnachweis; direkte Ausführung von `legacy-ci.ps1` ist nicht unterstützt.

Die historischen Befehlsnamen `restore-immutables` und `repin-immutables` werden am zentralen Einstieg auf `Repair`, `runtime-update` auf `Update` abgebildet. Dadurch bleiben vorhandene Aufrufe funktionsfähig, ohne die zentrale Vertrauensbasis lokal neu zu pinnen. Bytegenaue Referenz-Templates enthalten weiterhin die ursprüngliche Standalone-Semantik.

## Publikation

- Zielpfade werden kanonisiert und auf Containment, Windows-Aliase, ADS-Syntax und Reparse Points geprüft.
- Install, Update, Repair und Run verwenden denselben projektbezogenen OS-Dateilock.
- Erwartete Hashes stammen aus dem bereits verifizierten zentralen Release-Datensatz.
- Dateien werden zunächst in eine eindeutige Transaktion kopiert und dort verifiziert.
- Vorhandene Ziele, Konfiguration, Zielmanifest und Binding werden in einem transaktionsbezogenen Backup gesichert.
- Jede Datei wird atomar ersetzt; anschließend folgt eine Gesamtprüfung.
- Bei Fehlern werden alle Rollback-Schritte best-effort ausgeführt und separat berichtet.
- Backups bleiben absichtlich erhalten. Eine automatische Retention ist noch nicht aktiviert.

## Mutable und immutable Daten

Immutable sind ausschließlich ausführbarer Bootstrap-/Profilcode, Kataloge und Schemas. Mutable bleiben Konfiguration, README, Roadmap, Todo, Handoff und Logs. Historische lokale Pins werden nicht mehr als Autorität für den zentralen Modus verwendet.

## Versionsmodell

Profile tragen SemVer. Ein gebundenes Projekt startet nur, wenn seine installierte Profilversion dem zentralen Release entspricht. `Repair` darf kein Profil wechseln; `Update -Force` ist der explizite Profilwechselpfad.
