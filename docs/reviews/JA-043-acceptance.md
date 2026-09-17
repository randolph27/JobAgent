# JA-043 Akzeptanznachweis

Stand: 2026-09-17.

## Umgesetzter Vertrag

- `published_at` ist ein optionaler, ISO-8601-validierter Quellenwert im Schema und wird von der Statusmaschine nach UTC normalisiert. Fehlende Folgewerte loeschen den belegten Altwert nicht.
- Die Reportprojektion ordnet jede offene Stelle einer erfolgreichen Quellenbestaetigung derselben `source_id` zu und liefert `CURRENT`, `CHECK_PENDING` oder `FRESHNESS_UNKNOWN` gegen die feste Reportreferenz.
- Das 7-Tage-Fenster ist inklusiv. Offene, ueberfaellige Stellen bleiben im Bestand sichtbar; geschlossene, entfernte und ungueltige Stellen werden separat gezaehlt.
- Die Suchkarten zeigen Alter und Quellenstand. Der vollstaendige Feld-, Nullwert- und Migrationsvertrag steht in `docs/contracts/JA-043-jobboard-data.md`.

## Funktionstests

| Command | Exit | Abgedeckte Faelle |
|---|---:|---|
| `pwsh -NoProfile -File ./tests/Test-JobAgentSchema.ps1` | 0 | Schema, ungueltiges `published_at` |
| `pwsh -NoProfile -File ./tests/Test-JobAgentPersistence.ps1` | 0 | atomarer Altstore-Roundtrip und Migration |
| `pwsh -NoProfile -File ./tests/Test-JobAgentStatusMachine.ps1` | 0 | Statuswechsel, Fehler ohne `last_seen`-Fortschreibung, Publikationszeit-Normalisierung und -Erhalt |
| `pwsh -NoProfile -File ./tests/Test-JobAgentReport.ps1` | 0 | deterministische Projektion, fehlende Quellenbestaetigung, 7 Tage exakt und plus eine Sekunde |

Der Abschluss-Supertest wurde nach den Funktionstests gestartet. Sein Ergebnis wird erst bei vorliegendem Abschlussreport als Roadmap-Abschluss gewertet.

## Nicht enthalten

Keine Produktionsdaten-Umetikettierung, keine neue Job-ID-Bildung, keine privaten Markierungen und kein Liveabruf.
