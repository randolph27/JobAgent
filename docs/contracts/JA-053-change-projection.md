# JA-053 – Quellenchronik-Projektion

## Grundlage

Ein Chronikeintrag entsteht nur aus einer stabilen `job_id` und einem vorhandenen Change-Event. Verglichen werden ausschliesslich chronologisch benachbarte archivierte Snapshots derselben ID. Gleiche Titel verschiedener IDs werden nie zusammengefuehrt.

Die fachliche Feldliste lautet: `title`, `location`, `work_model`, `employment_type`, `work_time`, `description`, `requirements`, `salary`, `official_url` und `status`. Technische Laufdaten, Request-IDs, Rendererzeit und unveraenderte Verifikation sind kein Inhaltsereignis.

## Darstellung

Die Detailansicht bezeichnet den Zeitpunkt als „Aenderung erkannt am“. Sie zeigt Lauf, Quelle, Ereignistyp und die Feldwerte mit „Vorher“ und „Nachher“. HTML wird als Klartext behandelt; Unicode wird Form KC-normalisiert, Zeilenenden und Whitespace werden vereinheitlicht. Gross-/Kleinschreibung, Zahlen und Wortlaut bleiben erhalten.

Wenn kein frueherer Snapshot vorhanden ist, steht ausschliesslich „Vorheriger Inhalt nicht archiviert“. Ein Hash oder ein aktueller Text wird nicht als Alttext ausgegeben.

`JOB_CREATED`, `JOB_UPDATED`, `JOB_CLOSED` und `JOB_REMOVED` bleiben getrennte Ereignistypen. Ein Quellenfehler erzeugt weder `JOB_REMOVED` noch `JOB_CLOSED`. Die Reihenfolge ist absteigend nach Beobachtungszeit und bei Gleichstand aufsteigend nach `change_event_id`.

## Grenzen

Der Report uebergibt die komplette vorhandene Chronik. Die Detailansicht zeigt anfangs 20 Eintraege; weitere Eintraege bleiben ueber eine explizite Erweiterungsaktion erreichbar. Private Browserdaten werden nicht in die Quellenchronik geschrieben oder daraus abgeleitet.
