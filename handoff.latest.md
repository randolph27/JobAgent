# Handoff latest

Stand: 2026-09-22T14:07:59.734+02:00

## Zustand

- Active: `TD-0078`
- Status: `in-progress`
- Ziel: M3 - Publikation und Gesamtabnahme: JA-050 Stellenworkflow mit Wachstum, Markierungen und Grenzfaellen abnehmen #comment: Abschluss erfordert belegtes Zusammenspiel von regulaerem Lauf, Suche, Details, persoenlichen Markierungen und erneuter Publikation.
- Branch: `master`
- HEAD: `565040e6bd18`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `handoff.latest.md`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

`TD-0078` / `JA-050` bleibt aktiv. Zuerst den vollständigen lokalen Benchmark mit `pwsh -NoProfile -File .\tests\Test-JobAgentPerformance.ps1` erfolgreich abschließen und `logs/jobagent/JA-050/performance.json` sichern. Anschließend den vollständigen UI-Browseraudit gezielt gegen die nach `JA-048-stars-390.png` hängende Filterinteraktion reproduzieren und schließen.

## Technischer Stand für die Fortsetzung

- Teilbild 1 ist belegt: `Test-JobAgentAcceptance.ps1` prüft A/B/D -> A/B/C/D, vier Firmen, vier historische Stellen, drei offene Stellen, A1-Update, A2-Schließung, B-Quellenfehler, Markierungen, Ausblendung und Suchsichtung.
- Teilbild 2 hat grüne fokussierte Browsernachweise für Kalender, Bewerbungsübersicht, gespeicherte Suche und Ausblendung. Der vollständige `Test-JobAgentUiBrowserAudit.ps1` ist nicht als bestanden belegt.
- `tests/Test-JobAgentPerformance.ps1` ist neu. Standardumfang: 0/1/50/51/121/1000/10000 Stellen, fünf Warmups und 20 echte Filtermessungen je Menge, maximal 50 Karten, p95 <=500 ms und 10000er-Erstrender <=3 s. Ein fokussierter 121er-Lauf mit jeweils einer Messung war grün: p95 15,5 ms, Erstrender 139,2 ms.
- Mehrere unvollständige Performance-Artefakte wurden bereinigt. Ein verwaister Chrome-/Node-Lauf mit dem isolierten Profil `ja050-performance-4f9fa3c50f8b4f729871e68222228edb` hält noch Runtime-Dateien offen; dessen Prozessbezug vor einem Stop eindeutig verifizieren. Keine fremde Chrome-Sitzung beenden.
- Kein Supertest ausführen: Er gilt gemäß Nutzerauftrag als erledigt. `Test-JobAgentTestMatrix.ps1` scheitert derzeit erwartbar, weil `tests/Test-JobAgentSupertest.ps1` fehlt.
- Keine Roadmap-Rotation: ausschließlich `JA-050` ist offen.
