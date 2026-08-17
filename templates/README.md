# Verlustfreie Referenz-Templates

Jedes Unterverzeichnis enthaelt den bei der Erfassung vorhandenen Projektvertrag und die ausfuehrbaren CI-Dateien ohne inhaltliche Kuerzung:

- `README.md`
- `ci.cmd`
- `.ci/ci.config.json`
- `.ci/bin/**`
- `template.manifest.json`

Die Dateien werden aus den drei Quellprojekten ausschliesslich gelesen. Laufzeitdaten, Pins, Logs, Inbox, Caches und Test-Fixtures werden nicht uebernommen.

`template.manifest.json` speichert neben Hash und Groesse jeder Datei auch Git-HEAD und den Git-Status der ausgewaehlten Referenzdateien. Dadurch wird kenntlich, wenn eine Aufnahme bewusst lokale, noch nicht committete CI-Aenderungen enthaelt.

Die Referenz-Templates dienen dem Nachweis und der manuellen Ableitung. Sie werden nicht automatisch in ein Projekt kopiert. Fuer die gehaertete zentrale Installation werden die Profile unter `profiles/` und der Manager verwendet.
