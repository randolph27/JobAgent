# JA-051 Zeitprojektion

## Verbindliche Quelle und Referenz

Jeder Daily-Report verwendet genau `scan_runs[].finished_at` des ausgewaehlten `scan_run_id` als gespeicherte `reference_time`. Die Darstellung rechnet weder beim Rendern noch beim erneuten Oeffnen mit der Browser- oder Systemzeit. Zeitstempel werden in `Europe/Berlin` als ausgeschriebenes Datum, Uhrzeit und UTC-Offset dargestellt.

| Anzeige | Quelle | Praezision | Bedeutung |
|---|---|---|---|
| Veroeffentlicht | `jobs[].published_at` | Sekunde | Von der offiziellen Anzeige belegter Zeitpunkt mit Offset oder `Z`. |
| Veroeffentlicht | `jobs[].published_on` | Tag | Quelldatum ohne Uhrzeit; Anzeige benennt „Uhrzeit unbekannt“. |
| Erstmals erfasst | `jobs[].first_seen` | Sekunde | Erste bestaetigte Erfassung dieser `job_id`. |
| Zuletzt bei dieser Stelle gesehen | `jobs[].last_seen` | Sekunde | Letzte erfolgreiche Sichtung genau dieser `job_id`. |
| Letzter Abrufversuch | `scan_attempts[]` | Sekunde | Letzter Versuch derselben `source_id`, auch bei Fehler. |
| Letzter erfolgreicher Abruf | `scan_attempts[]` | Sekunde | Letzter `SUCCESS` mit `error_class=NONE`. |
| Letzte vollstaendige Listenpruefung | `scan_attempts[]` | Sekunde | Letzter erfolgreicher Versuch mit `scan_complete=true`. |
| Naechste Firmenpruefung | `companies[].next_scan_at` | Sekunde | Firmenplanung, kein garantierter Jobtermin. |

`SUCCESS` ohne `scan_complete=true` ist kein Vollstaendigkeitsbeleg. Fehler und PARTIAL aktualisieren keine vollstaendige Listenpruefung. Ein im PARTIAL-Abruf konkret beobachteter Job darf dagegen seine eigene `last_seen`-Zeit aktualisieren. Ein erfolgreicher Vollabruf ohne diesen Job aktualisiert dessen `last_seen` nicht.

## Altersregeln

Altersbasis ist in dieser Reihenfolge `published_at`, `published_on`, `first_seen`. Bei Zeitstempeln gilt `floor((reference_time - event_time) / 86400 Sekunden)`; unter 24 Stunden wird damit `0` ausgegeben. Bei einem tagesgenauen Quelldatum gilt die Kalenderdifferenz der Berliner lokalen Tage. Ein fehlender Offset, ungueltiger Text, fehlende Historie oder Zukunftszeitpunkt ergibt `UNKNOWN`; Zukunft erzeugt einen Datenhinweis statt eines negativen Alters.

`published_at` ohne Offset wird nicht gespeichert. Ein Datum `YYYY-MM-DD` wird als `published_on` ohne erfundene Mitternachtszeit gespeichert. Alte Daten ohne die benoetigten Belege bleiben lesbar und werden als „Historie nicht vorhanden“ beziehungsweise „Zeitpunkt ohne Offset ist nicht eindeutig“ ausgewiesen.

## Determinismus

Die Projektion pro Stelle liegt im Report unter `time_projection` mit Referenz, Zone, Zeitpraezision, Datenhinweis sowie Attempt-/Run-IDs. Dieselbe Storegeneration und Referenz erzeugen identische Werte. Die Fixture `tests/fixtures/jobagent/time-projection.json` deckt Tagespraezision, fehlenden Offset, Zukunft und die beiden unterschiedlichen UTC-Zeitpunkte beim DST-Rueckwechsel ab.
