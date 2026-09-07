# Handoff JA-027.3 Einzelresultat-Resume

Stand: 2026-09-07 08:45 Europe/Berlin

## Aktiver Punkt

- Todo: `TD-0041`
- Roadmap: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`
- Keine Roadmap-Rotation: JA-027 ist fachlich nicht komplett erledigt. Offen bleiben echter 100-Kandidaten-Live-Benchmark, Quellen-Nachfuellung bis 1.000 und Host-/Redirect-/ATS-Concurrency.
- Supertest: vom Nutzer fuer diesen Wechsel als erledigt gewertet; technisch nicht ausgefuehrt und nicht als Testnachweis genutzt.

## Erledigter Arbeitsschritt

`tools/Verify-JobAgentCompanyCandidates.ps1` hat jetzt ein verlustfreies Einzelresultat-Resume fuer den Bereich zwischen Netzwerkphase und Store-Commit.

Umgesetzt:

- `running`-Checkpoint enthaelt `candidate_ids`, `completed_candidate_ids`, `pending_candidate_ids`, `result_checkpoint_root` und `commit_applied_at`.
- Jedes Kandidatenresultat wird vor dem Store-Commit atomar unter `data/jobagent/company-candidate-verification.checkpoint.json.results/<sha256(candidate_id)>.json` gesichert.
- Ein Folgelauf mit offenem `running`-Checkpoint und leerem `commit_applied_at` laedt vorhandene Resultate, verarbeitet nur fehlende Kandidaten und committet danach seriell.
- Der completed-Checkpoint dokumentiert Commitzeitpunkt und Batch-Metriken.
- Jeder regulaere Lauf schreibt `logs/jobagent/JA-027-resume-<run-id>.json` und fuehrt denselben Report im Batchmanifest als `resume_report`.
- Testschalter `-StopBeforeCommitForResumeTest` simuliert den Abbruch nach Ergebnischeckpoint und vor Store-Commit; er ist fuer deterministische Tests gedacht.

## Geaenderte Dateien

- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `docs/company-discovery-operations.md`
- `Roadmap.md`
- `todo.state.json`
- `handoff.latest.md`
- `handoff.latest.json`
- STP-Dateien: `todo.events.jsonl`, `todo.history.digest.json`, `todo.master.index.json`

## Verifikation

Gruen:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1
pwsh -NoProfile -File .\tests\Test-JobAgentCoverage.ps1
git -c core.pager=cat -c color.ui=false --no-pager diff --check
cmd /c .\ci.cmd self-check
cmd /c .\ci.cmd devserver-status
```

Nicht gruen / Blocker:

```powershell
curl.exe -s http://localhost:9000/api/system/status
cmd /c .\ci.cmd sonar-start
```

SonarQube ist ueber `localhost:9000` nicht erreichbar. `sonar-start` schlaegt fehl, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt. Der Devserver auf `8500` laeuft.

## Naechste Aufgaben

1. `JA-027.3` fortsetzen und vor Live-Netzarbeit Eligibility pruefen:
   - `data/jobagent/company-discovery.hints.json`
   - `data/jobagent/company-candidate-verification.queue.json`
   - Kriterien: `PENDING`, `VERIFY_OFFICIAL_SITE`, faelliges `next_attempt_at`, unterscheidbare Kandidaten.
   - Wenn weniger als 100 Kandidaten faellig sind, konkrete Ursache dokumentieren; kein No-op als Benchmark werten.

2. Produktiven 100-Kandidaten-Live-Benchmark vorbereiten und ausfuehren:
   - Einstieg: `pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1`
   - Vorher Store-/Queue-/Checkpoint-Zustand sichern.
   - Danach `logs/jobagent/JA-027-batch-<run-id>.json` und `logs/jobagent/JA-027-resume-<run-id>.json` gegen Nenner, Nettozuwachs, Retry/Review und Resultatcheckpoint pruefen.

3. Host-/Redirect-/ATS-Concurrency nachschaerfen:
   - Aktuell begrenzt die Auswahl Initialhosts.
   - JA-027 verlangt hoechstens einen gleichzeitigen Request je tatsaechlichem Host inklusive Redirect-/ATS-Ziel.
   - Dafuer gezielten Funktionstest ergaenzen; keine globale Scheduler-Behauptung ohne Test.

4. Quellen-Nachfuellung bis 1.000 offizielle Karriere-/ATS-Arbeitgeber planen:
   - `logs/jobagent/JA-027-source-research.json` respektieren.
   - HWK nicht automatisiert importieren.
   - BioM/IHK nur mit separatem Snapshot-/Export-/API-Vertrag.
   - Stadt Freising Wirtschaft nicht als allgemeine neue Quelle nutzen.

5. JA-027 erst rotieren, wenn fachlich komplett:
   - 1.000 belegte offizielle Karriere-/ATS-Arbeitgeber oder konkrete, dokumentierte Restblockade.
   - Batch-, Resume- und 1.000er-Evidence vorhanden.
   - Funktionstests gruen.
   - Roadmap/Todo/Handoff synchron.

## Risiken

- `-MaxCandidates 100` garantiert weiterhin keine 100 verarbeiteten Kandidaten, wenn Eligibility oder Hostlimit weniger zulassen.
- Queue kann aktuell keine faelligen PENDING-Kandidaten enthalten.
- Resume ist deterministisch fixturegetestet; ein echter Live-Abbruch mit Netzwerk-/Retry-Mix ist noch nicht als 100er-Benchmark belegt.
- SonarQube-Start ist lokal durch fehlendes `sonar.cmd` im Projektroot blockiert.
