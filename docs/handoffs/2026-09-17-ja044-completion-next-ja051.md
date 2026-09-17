# Uebergabe – JA-044 abgeschlossen, Einstieg JA-051

Stand: 2026-09-17. Arbeitszweig: `master`.

## Abgeschlossen

JA-044 ist fachlich abgeschlossen und nach `Roadmap_archive.md` rotiert. Der vorhandene Produktionscode hatte keine nachweisbare Uebergabeluecke; implementiert wurden deshalb nur der fehlende deterministische Integrationsnachweis und seine Planungs-/Akzeptanzdokumentation.

- Neue Fixture: `tests/fixtures/jobagent/ja-044-acquisition-replay.json`.
- Neuer Test: `tests/Test-JobAgentJa044AcquisitionReplay.ps1`.
- Neue Abnahme: `docs/reviews/JA-044-acceptance.md`.
- Testmatrixeintrag fuer JA-044: `docs/test-matrix.json`; `docs/reviews/QA-001-function-inventory.json` wurde kanonisch mit `-WriteInventory` regeneriert und hat 579 Eintraege.
- Reproduktion ohne Netzwerk oder Produktivdaten: bekannte Alpha AG, neue verifizierte Beta GmbH, Doppelhinweis und leere Gamma GmbH. Feste externe Job-IDs: `alpha-100`, `beta-200`.

Der Replay beweist: identischer Zweitlauf ohne Dublette, vollstaendiger Beta-Leerscan entfernt nur `beta-200`, Timeout und Teilscan lassen `alpha-100` aktiv und `PARTIAL`, ein Restart bewahrt alle drei Firmen. Die ignorierte Lauf-Evidence liegt unter `logs/jobagent/JA-044/acquisition-replay.json`, SHA-256 `0d5c3b1a7c18270a88c17073f7e67255663f3c678c7cb8e3add457dbfefd6e93`.

## Belegte Tests

Alle folgenden Funktionstests endeten mit Exit `0`:

- `Test-JobAgentCompanyInventory.ps1` – 18 Faelle.
- `Test-JobAgentSourceVerification.ps1` – 28 Faelle.
- `Test-JobAgentSourceAdapters.ps1` – 12 Faelle.
- `Test-JobAgentDailyRun.ps1` – 22 Faelle.
- `Test-JobAgentCoverage.ps1` – 18 Faelle.
- `Test-JobAgentJa044AcquisitionReplay.ps1` – 6 Faelle.
- `Test-JobAgentTestMatrix.ps1 -WriteInventory` und danach ohne Schalter – Matrix 9 Faelle, Inventar 579.

Ein Vollsupertest wurde nicht ausgefuehrt: Er war nicht angefragt und gilt nach Nutzerregel als erledigt. Kein Browser-, Emulator-, Livecrawl- oder Sonar-Lauf gehoerte zu JA-044.

## Naechster Arbeitspunkt: JA-051

Beginne mit JA-051 „Stellenalter, Abrufalter und naechste Pruefung aus belegten Zeitdaten ableiten“ (Todo `TD-0079`). Abhaengigkeiten JA-043 und JA-044 sind abgeschlossen.

Ziel ist eine einzige deterministische Zeitprojektion, nicht eine zweite Alterslogik:

1. Feldmatrix und Vertrag unter `docs/contracts/JA-051-time-projection.md` anlegen. Trenne pro Job `published_at`, `first_seen`, `last_seen`; trenne pro Quelle letzten Versuch und letzte vollstaendige erfolgreiche Listenpruefung; behandle `company.next_scan_at` als Firmenplanung. Lege Herkunft, ISO-8601-/Offset-Anforderung, Praezision, Nullwert und Anzeige fest.
2. Feste Fixture `tests/fixtures/jobagent/time-projection.json` vorbereiten: Referenzzeit, exakt 24 Stunden und 7 Tage jeweils plus/minus eine Sekunde, unbekannte/ungueltige/mehrdeutige Werte, reines Datum ohne Uhrzeit, Zukunftsdatum, Fehler nach Erfolg, Teilabruf mit bestaetigtem Einzeljob, vollstaendige Liste ohne Job und beide Zeitpunkte der DST-Umstellung am 2026-10-25.
3. Erst danach bestehende Schema-, Status-, Report-, Daily-Run-, Operations- und Persistenzprojektion minimal erweitern. Relative Werte eines Reports muessen dieselbe gespeicherte `reference_time` benutzen. Eine erfolgreiche Liste ohne wiedergefundene Stelle darf deren `last_seen` nicht aktualisieren. Fehler/PARTIAL duerfen keinen vollstaendigen Listenabruf behaupten.
4. Karten, Details und spaetere Kalenderdaten nur aus derselben Projektion ableiten. Zeitdarstellung Europe/Berlin mit ausgeschriebenem Datum/Uhrzeit und Offset im Detail; Tagespraezision getrennt als „Uhrzeit unbekannt“, keine Interpretation als 00:00 UTC; Zukunftsereignisse als Datenhinweis ohne negatives Alter.

Vorgesehene JA-051-Funktionstests: `Test-JobAgentSchema.ps1`, `Test-JobAgentStatusMachine.ps1`, `Test-JobAgentReport.ps1`, `Test-JobAgentOperations.ps1` plus neue gezielte Fixturefaelle. Supertest erst nach fachlichem Abschluss, falls er dann angefragt wird.

## Grenzen und Arbeitshinweise

- Keine Livequellen als Testorakel verwenden; keine Produktivdaten, Quellbudgets, Retry-/Hostlimits oder Retention fuer JA-051 aendern.
- Aktive Roadmap-Reihenfolge: `JA-051 -> JA-045 -> JA-046 -> JA-047 -> JA-048 -> JA-052 -> JA-053 -> JA-055 -> JA-049 -> JA-054 -> JA-056 -> JA-050`.
- Vor einem Devserverlauf auf Port 8500 `./ci.cmd devserver-status` verwenden; Start ausschliesslich ueber `./ci.cmd devserver-start` im Hintergrund.
- Sonar bleibt auf Port 9000, wird nur bei konkretem Sonar-Arbeitspunkt ueber `./ci.cmd sonar` ausgefuehrt.
- Der Worktree enthielt beim letzten `stp` ausschliesslich die fachbezogenen JA-044- und Synchronisationsaenderungen. Elf bereits vorhandene ignorierte Sonar-Legal-Dateien unter `.ci/tools/sonar/...` bewirken den bekannten Route-Check-Hinweis; sie sind nicht Teil dieser Uebergabe und wurden nicht veraendert.
