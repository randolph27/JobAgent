# Handoff latest

Stand: 2026-09-06T08:20:37.278+02:00

## Zustand

- Active: `TD-0041`
- Status: `in-progress`
- Ziel: JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen #comment: Vorhandene Kandidaten und Websitehinweise automatisch nutzen, damit nicht mehr jede Handvoll Firmen einen eigenen manuellen Chat-Slice benötigt.
- Branch: `master`
- HEAD: `1f2ecb1a3f1a`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `True`

## Versionierte Aenderungen

- `Roadmap.md`
- `handoff.latest.json`
- `handoff.latest.md`
- `src/JobAgent.SourceVerification.psm1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `todo.events.jsonl`
- `todo.history.digest.json`
- `todo.master.index.json`
- `tools/Verify-JobAgentCompanyCandidates.ps1`

## Verifikation

- `.\ci.cmd sonar` -> Exit ``

## Uebergabe an den naechsten Agenten

- Aktiver Punkt: `TD-0041` / JA-027. Nicht abschliessen oder archivieren: Weder 1.000 offiziell belegte Karriere-/ATS-Quellen noch der reale 100-Kandidaten-Benchmark sind nachgewiesen.
- Erster von maximal zwei Teilslices ist abgeschlossen. `tools/Verify-JobAgentCompanyCandidates.ps1` trennt Netzverifikation und Schreibphase: ohne Fixture bis zu vier PowerShell-Worker, bekannte Hosts standardmaessig auf einen Kandidaten begrenzt, danach ein serieller Writer mit Store-Backup. Fixture-Läufe bleiben absichtlich seriell.
- Resume-Vertrag: `data/jobagent/company-candidate-verification.checkpoint.json` enthält `running`/`completed`, Kandidaten-IDs und Batchmetriken. HTTP 429 nutzt `Retry-After`, sonst bleibt exponentieller Backoff aktiv.
- Verifiziert: `Test-JobAgentRegionalDiscovery.ps1`, `Test-JobAgentSourceVerification.ps1`, `Test-JobAgentCompanyCandidateVerification.ps1` (einschließlich echter Parallelpfad ohne externe Quelle), `Test-JobAgentImportWaves.ps1`, `Test-JobAgentCompanyDedupeScale.ps1` jeweils Exit 0; `git diff --check` sauber; `.\ci.cmd stp` Exit 0.
- Nächster Schritt: produktiven, quellenkonformen 100-Kandidaten-Benchmark ausführen. Vorher Queue, Checkpoint und Store-/Backupzustand prüfen. Danach `logs/jobagent/JA-027-batch-*.json` mit Quellenprovenienz, netto verifizierten Arbeitgebern/min, P50/P95, Requests je Firma, Fehler-/Reviewquote und Restmenge ablegen. Ohne Messwert keine ETA behaupten.
- JA-041 darf vorbereitet werden, aber der aktive Todo-Eintrag bleibt JA-027.

## Naechster Anker

JA-027, zweiter Teil-Slice: echten 100-Kandidaten-Benchmark mit Quellenbudgets ausführen und Durchsatz, P50/P95, Requests je Firma sowie Fehler-/Reviewquote als Evidence ablegen. Das 1.000er-Ziel bleibt bis zum belegten Live-Lauf offen.
