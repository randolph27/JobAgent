# Uebergabe – JA-051 abgeschlossen, Einstieg JA-045

Stand: 2026-09-17. Arbeitszweig: `master`.

## Abgeschlossen: JA-051 Zeitprojektion

JA-051 „Stellenalter, Abrufalter und naechste Pruefung aus belegten Zeitdaten ableiten“ ist fachlich abgeschlossen, getestet und aus der aktiven Roadmap nach `Roadmap_archive.md` rotiert.

- `src/JobAgent.Report.psm1` liefert die zentrale Zeitprojektion. Bei einem gueltigen Zeitstempel mit Sekundenpraezision und Alter `0` lautet die Anzeige jetzt `Unter 1 Tag`; die maschinenlesbaren Werte und vollstaendigen Zeitstempel bleiben unveraendert erhalten.
- `tests/fixtures/jobagent/time-projection.json` deckt Vorher/Nachher der Zeitumstellung, unter/genau/ueber 24 Stunden und 7 Tagen, Tagespraezision, Zukunft, fehlenden Offset und ungueltige Zeitwerte ab.
- `tests/Test-JobAgentReport.ps1` prueft den Hinweis fuer ungueltige Zeitwerte sowie die Anzeige unter 24 Stunden.
- `docs/contracts/JA-051-time-projection.md` beschreibt Feldherkunft, Referenzzeit, Praezision, Zeitzone und Nullwertverhalten.
- `docs/reviews/JA-051-acceptance.md` ist der Abnahmenachweis. Die ignorierte Lauf-Evidence liegt unter `logs/jobagent/JA-051/time-cases.json`.

Zeitvertrag fuer Folgepunkte: Relative Werte eines Reports werden aus dessen fester `reference_time` berechnet. Zeitstempel mit Uhrzeit behalten ISO-8601-Offset und werden in Europe/Berlin dargestellt. Reine Daten bleiben Tagespraezision (`Uhrzeit unbekannt`) und werden nicht als `00:00 UTC` interpretiert. Zukunftswerte werden als Datenhinweis gezeigt, nie als negatives Alter. Job-Zeiten (`published_at`, `first_seen`, `last_seen`), Abrufversuche und erfolgreiche vollstaendige Listenpruefungen bleiben getrennte Fakten; ein Fehler oder PARTIAL behauptet keine vollstaendige Liste.

## Verifikation

Folgende Funktionstests endeten mit Exit `0`:

- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentStatusMachine.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentOperations.ps1`
- `pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1`

Der erste Abschluss-Supertest scheiterte ausschliesslich an einem veralteten kanonisch generierten QA-001-Funktionsinventar. Dieses wurde mit `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1 -WriteInventory` regeneriert; anschliessend war der Matrix-Test gruen (Matrix 9 Faelle, Inventar 584 Eintraege). Der erneute Abschlusslauf war erfolgreich:

```text
.\ci.cmd supertest
planned=29, passed=29, failed=0, blocked=0, not_run=0
```

Kein Devserver-, Browser-, Emulator-, Livecrawl- oder Sonar-Lauf war fuer JA-051 erforderlich.

## Synchronisierter Planungsstand

- `Roadmap.md`: 11 aktive Punkte, JA-051 entfernt.
- `Roadmap_archive.md`: JA-051 mit Nachweisen archiviert.
- `Roadmap_index.md`: Rotation und naechster Anker aktualisiert.
- `todo.current.md`, `todo.state.json`, `todo.master.index.json`, Checkpoint und History: TD-0079 abgeschlossen; als erster aktiver Punkt steht TD-0073 / JA-045.

Die aktive Reihenfolge ist:

```text
JA-045 -> JA-046 -> JA-047 -> JA-048 -> JA-052 -> JA-053 -> JA-055 -> JA-049 -> JA-054 -> JA-056 -> JA-050
```

## Naechster Arbeitspunkt: TD-0073 / JA-045

JA-045 implementiert einen verlustarmen, browserlokalen Zustand fuer Favoriten und „Schon beworben“ je stabiler `job_id`.

1. Einen DOM-unabhaengigen v1-Zustandsvertrag anlegen: stabiler Origin `http://127.0.0.1:8500`, localStorage-Key `jobagent:personal:v1`, Schema `jobagent-user-state/v1`. Pro Job sind `favorite`, `applied`, `favorite_updated_at`, `applied_updated_at` und `applied_at` getrennt; alle vier Boolean-Kombinationen sind zulaessig. `applied` einschalten setzt `applied_at`, ausschalten leert nur dieses Feld. Gleiche Schreiboperationen sind idempotent.
2. Geplante Artefakte zuerst gegen die bestehende Codebasis abgleichen: `html/jobagent/assets/jobboard-state.js`, `schemas/jobagent.user-state.schema.json`, `tests/Test-JobAgentUserState.ps1` und `tests/fixtures/jobagent/user-state/`. Die Roadmap enthaelt die vollstaendige Zustands-, Recovery- und Import-/Exportmatrix.
3. Fehlerfaelle sind Teil des Vertrags: blockierter Speicher, Quota, korruptes JSON und unbekannte Version duerfen Originaldaten nicht ueberschreiben und muessen „Nicht dauerhaft gespeichert“ anzeigen. Import erst nach vollstaendiger Validierung und Vorschau; pro Feld gewinnt die juengere gueltige UTC-Zeit, Gleichstand behaelt den vorhandenen Wert. Nicht enthaltene Jobs werden nicht geloescht. Vor Schreibvorgaengen neu lesen und `storage`-Events fuer andere Tabs beruecksichtigen.
4. Keine Konten, Cloud-/Geraetesynchronisierung, neuen HTTP-Schreibserver, automatische Bewerbung oder reale persoenliche Daten einfuehren. Geschlossene oder entfernte Jobs behalten lokale Markierungen. Funktionslose Stern-Buttons gehoeren noch nicht in die UI; deren Bedienung ist JA-048.

Zuerst nur passende Funktionstests ausfuehren, insbesondere den neuen `Test-JobAgentUserState.ps1` und `Test-JobAgentReport.ps1`. Ein Supertest ist nach der Nutzerregel als erledigt zu behandeln, sofern er nicht erneut angefragt wird.

## Bekannter, nicht fachlicher Hinweis

TD-0085 „CI: Resolve drift (observer/route/immutables)“ wurde durch den automatischen CI-Observer angelegt. Ursache sind vorhandene Drittanbieter-Legal-Dateien unter `.ci/tools/sonar/...`, deren Inhalt den Route-Check stoert. Dieser Hinweis gehoert nicht zu JA-051 oder JA-045 und ist kein Produktblocker. Keine Dateien dieses Toolbestands ohne eigenen Auftrag loeschen oder veraendern.

Vor einem künftigen Devserverlauf `./ci.cmd devserver-status` nutzen; Start ausschliesslich ueber `./ci.cmd devserver-start` im Hintergrund auf Port 8500. Sonar nur bei einem konkreten Sonar-Arbeitspunkt ueber `./ci.cmd sonar`.
