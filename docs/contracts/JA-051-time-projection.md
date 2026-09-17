# JA-051 Zeitprojektion

## Geltungsbereich

Dieser Vertrag definiert die einzige Zeitprojektion fuer Stellenkarten, Details, Quellenansicht und spaetere Kalenderansichten. Sie wird aus dem gespeicherten JobAgent-Dokument abgeleitet und erzeugt keine Zeitwerte aus dem Renderzeitpunkt.

## Referenz und Darstellung

- `reference_time` ist `scan_runs[].finished_at` der gerenderten Generation und wird als UTC gespeichert.
- Zeitstempel muessen ISO 8601 mit `Z` oder numerischem Offset sein. Die Anzeige erfolgt in `Europe/Berlin` als ausgeschriebenes Datum, Uhrzeit und Offset.
- Altersdauer ist `floor((reference_time - event_time) / 86400 Sekunden)`. Bei gueltigem Zeitstempel unter 24 Stunden lautet die Altersanzeige `Unter 1 Tag`.
- `published_on` ist ein Tageswert ohne Uhrzeit. Sein Alter ist die Kalenderdifferenz zum Berliner Referenztag; die Anzeige nennt `Uhrzeit unbekannt`.
- Fehlende, mehrdeutige, ungueltige oder zukuenftige Vergangenheitszeitpunkte bleiben `UNKNOWN` und tragen einen Datenhinweis. Geplante `next_scan_at`-Zeitpunkte sind davon ausgenommen.

## Feldmatrix

| Feld | Herkunft | Praezision | Semantik |
| --- | --- | --- | --- |
| `published_at` | Quellanzeige | Zeitpunkt | Belegtes Veroeffentlichungsdatum |
| `published_on` | Quellanzeige | Tag | Quelltag ohne erfundene Uhrzeit |
| `first_seen` | erste erfolgreiche Einzeljobsichtung | Zeitpunkt | Erstmals erfasst, kein Publikationsdatum |
| `last_seen` | letzte erfolgreiche Einzeljobsichtung | Zeitpunkt | Nur der konkret gefundene Job; eine leere Erfolgsliste erneuert ihn nicht |
| letzter Abrufversuch | `scan_attempts` | Zeitpunkt | Neuester dokumentierter Versuch, auch Fehler/Teilabruf |
| letzter erfolgreicher Abruf | `scan_attempts` mit `SUCCESS`/`NONE` | Zeitpunkt | Neuester erfolgreicher Quellenabruf |
| letzte vollstaendige Listenpruefung | erfolgreicher `scan_attempt` mit `scan_complete=true` | Zeitpunkt | Kein Ersatz durch Fehler oder unvollstaendigen Abruf |
| naechste Firmenpruefung | `companies[].next_scan_at` | Zeitpunkt | Firmenplanung, kein garantierter Jobtermin |

Fehlende Altbelege werden als `Historie nicht vorhanden` ausgegeben. Die bestehende Aktualitaetsschwelle bleibt exakt sieben mal 24 Stunden; Tageswerte behaupten keine Stundenfrische.

## Replay

Bei identischem Store und identischer `scan_run_id` ist die Projektion deterministisch. Zeitwerte, Ereignis- und Versuchs-IDs werden weder aus Browserzeit noch aus Dateizeit rekonstruiert.
