# Handoff: JA-041.1 abgeschlossen, JA-041.2 als Fortsetzung

Stand: 2026-09-15

## Aktiver Roadmap- und Todo-Stand

- Aktiver Todo: `TD-0053` / `JA-041 Berufsneutrale Stellenerfassung von Suchprofilen trennen`.
- `JA-041.1 Erfassung ohne impliziten Berufsfilter als Standard liefern` ist abgeschlossen und bleibt als erledigter Unterpunkt in `Roadmap.md`.
- `JA-041` wird nicht archiviert: `JA-041.2` und `JA-041.3` sind noch offen.
- `UI-001` und `JA-042` bleiben nachrangig; sie bauen auf der allgemeinen Stellenbasis aus JA-041 auf.
- Ein Supertest ist fuer diesen Abschluss nicht auszufuehren. Nach Nutzervertrag gilt ein nicht angefragter Supertest als erledigt.

## Gelieferter Vertrag aus JA-041.1

1. `tools/Invoke-JobAgentDailyRun.ps1` und `New-JobAgentLiveScanPolicy` verwenden leere `SearchTerms` als Standard. Der Policywert `collection_scope` ist dann `ALL_ROLES`; nichtleere Begriffe ergeben weiterhin `EXPLICIT_TERMS`.
2. Die historische IT-Fallbackliste (`Head of IT`, `Director IT`, `IT Leitung`, `IT-Leitung`, `Leiter IT`, `CIO`) wird nicht mehr automatisch eingesetzt.
3. Allgemeine Avature-Listen verwenden `/Jobs?folderRecordsPerPage=20`, statt pro Begriff eigene Suchpfade zu erzwingen. Die vorhandene begrenzte Suche mit expliziten Begriffen bleibt erhalten.
4. SuccessFactors verwendet bei leerem Scope die allgemeine Suchseite mit leerem `q`; der frühere RSS-Fallback mit `IT` wird nicht erzeugt.
5. `JobSource.search_term_requirement` ist optional im Schema. Bei `REQUIRED` und leerem Scope liefert der Live-Adapter `PARTIAL`, `TECHNICAL_LIMITATION`, `MANUAL_REVIEW` und `source_requires_search_terms_for_all_roles`. Damit wird keine Vollstaendigkeit oder ein vollstaendiger Nulltreffer behauptet.
6. Allgemeine Kandidaten mit offizieller konkreter Job-URL werden nicht wegen fehlender IT-Begriffe verworfen. Navigation, News, Login- und Bewerbungsseiten bleiben weiterhin ausgeschlossen.

## Nachweise

- Lokales Evidence-Artefakt: `logs/jobagent/JA-041-1-acceptance.json`.
- `pwsh -NoProfile -File .\tests\Test-JobAgentLiveScan.ps1` -> Exit 0. Deckt `ALL_ROLES`, Buchhaltung/Pflege, allgemeines Avature, allgemeines SuccessFactors ohne IT-RSS-Fallback und termpflichtige Quellen ab.
- `pwsh -NoProfile -File .\tests\Test-JobAgentDailyRun.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceAdapters.ps1` -> Exit 0.
- `pwsh -NoProfile -File .\tests\Test-JobAgentSchema.ps1` -> Exit 0; lief außerhalb der Sandbox mit dem vorhandenen lokalen npm-Cache.
- `cmd /c .\ci.cmd stp` -> Exit 0.

## Naechster zusammenhaengender Slice: JA-041.2

Ziel: Offizielle Stellengueltigkeit, Gebiet und optionale IT-Profilpassung trennen. Eine belegte Pflege- oder Buchhaltungsstelle darf nicht wegen `classification.result = REJECTED` aus Persistenz oder Statusmaschine verschwinden. Nicht-Stellen, unbelegte Quellen und Orte außerhalb des Zielgebiets bleiben weiterhin ausgeschlossen.

Primärer Scope laut Roadmap:

- `src/JobAgent.Classification.psm1`
- `src/JobAgent.DailyRun.psm1`
- `src/JobAgent.Persistence.psm1`
- `src/JobAgent.StatusMachine.psm1`
- `schemas/jobagent.schema.json`
- zugehörige fokussierte Tests: `Test-JobAgentClassification.ps1`, `Test-JobAgentDailyRun.ps1`, `Test-JobAgentStatusMachine.ps1`

Arbeitsreihenfolge:

1. Aktuelle Übergabe von Rohstelle, Klassifikation und Statusmaschine nachvollziehen. Feststellen, ob `REJECTED` derzeit als Speichervoraussetzung oder nur als Anzeige-/Prioritätsinformation wirkt.
2. Additiven Datenvertrag für offizielle Validität, Standortbewertung und optionale Profilpassung definieren. Fehlende Attribute bleiben `UNKNOWN`; Titel, Arbeitgeber, Stellenort, Arbeitsmodell, Anstellungsart, Datumsfelder und offizielle URL dürfen nicht gelöscht oder erfunden werden.
3. Isolierte Fixtures für echte nicht-IT-Stellen, Nicht-Stellen, Muenchen, Freising, außerhalb und `UNKNOWN` ergänzen. Profilwechsel darf keine `NEW`, `CLOSED` oder `REMOVED`-Ereignisse erzeugen.
4. Erst nach nachgewiesenem Unterpunkt `JA-041.2` Roadmap, Todo, Handoff und STP zusammen synchronisieren. `JA-041` erst nach abgeschlossenem Unterpunkt `JA-041.3` archivieren.

## Grenzen

- Keine neue Firmenakquise-Welle, keine Gebietsaufweitung, keine UI-Filterarbeit und keine Bewerbungsautomatisierung in JA-041.2.
- Keine Live-Webrecherche in Funktionstests.
- Keine Aussage über Vollstaendigkeit bei Limits, Pagination, Timeout, Fehlern oder termpflichtigen Quellen.
