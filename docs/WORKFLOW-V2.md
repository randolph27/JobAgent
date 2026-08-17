# Workflow V2: verlustfreie Zielarchitektur

## Problem

Die drei Altbestände kombinieren JSONL-Events, State, Master-Index, Checkpoint, Roadmap und Archive mit unterschiedlichen Schemas. Es fehlen teilweise Event-IDs, ISO-Zeitstempel und Checkpoint-Grenzen. Ein semantisches Replay würde Annahmen erfinden.

## Zielmodell

Jeder Commit des Workflow-Zustands erzeugt eine neue immutable Generation:

```text
.workflow/
├─ CURRENT.json                       atomar ersetzter Pointer
└─ generations/
   └─ <generation-id>/
      ├─ generation.json              Hashes und Grenzen
      ├─ state.json                   materialisierter Zustand
      ├─ checkpoint.json              optional
      └─ events/
         ├─ 000001-001000.jsonl
         └─ 001001-....jsonl
```

`CURRENT.json` enthält Generation-ID und SHA-256 des Generationsmanifests. Ein OS-Dateilock schützt Writer. Leser öffnen zuerst den Pointer, prüfen Manifest und Artefakthashes und verwenden danach nur diese Generation.

## Eventvertrag

- streng monotone `sequence`;
- global eindeutige `event_id`;
- UTC-ISO-8601 in `ts`;
- `previous_event_hash` und kanonisch berechneter `event_hash`;
- expliziter Eventtyp und versioniertes Payloadobjekt;
- keine Mutation veröffentlichter Segmente.

Ein Segmentdescriptor enthält Dateihash, Eventzahl, erste/letzte Sequenz sowie die Hashgrenzen. Ein Checkpoint nennt exakt `through_sequence`, `through_event_id` und `through_event_hash`.

## Schreibprotokoll

1. exklusiven Workflow-Lock erwerben;
2. CURRENT und aktive Generation vollständig validieren;
3. neue Events mit fortlaufender Sequenz und Hashkette in Staging schreiben;
4. State deterministisch materialisieren;
5. Segmente, State, Checkpoint und Generationsmanifest hashen;
6. vollständige Generation in ihren finalen, neuen Pfad verschieben;
7. `CURRENT.json` atomar ersetzen;
8. Lock freigeben.

Bei einem Fehler vor Schritt 7 bleibt die alte Generation aktiv. Staging kann anhand seiner eindeutigen ID sicher quarantänisiert werden.

## Migrationsprotokoll

Für jedes Projekt separat:

1. Altdateien bytegenau inventarisieren und hashen.
2. Nur syntaktisch eindeutige Fakten extrahieren; Kulturzeitstempel mit Originaltext und interpretierter Zeitzone protokollieren.
3. Duplikate, fehlende IDs, duale Schemas und Roadmap-Konflikte in einen Migrationsreport schreiben.
4. Unentscheidbare Fälle nicht automatisch zusammenführen. Als `migration.snapshot` mit Herkunft und Konfliktstatus erhalten.
5. Kandidatengeneration erzeugen, aber CURRENT noch nicht setzen.
6. State-, Zähler-, ID- und Stichprobenabgleich durchführen.
7. Menschliche Freigabe der Konfliktliste.
8. CURRENT atomar publizieren; Altdateien read-only archivieren, nicht löschen.

Die mitgelieferten JSON-Schemas definieren Pointer, Generation, Segment, Event, State und Checkpoint. Release 1.0.0 aktiviert dieses Format noch nicht; es liefert Audit und Verträge als sichere Grundlage.

