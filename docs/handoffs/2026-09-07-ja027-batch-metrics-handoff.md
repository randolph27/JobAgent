# Handoff JA-027.3 Batch-Metriken

Stand: 2026-09-07 08:15 Europe/Berlin

## Aktiver Punkt

- Todo: `TD-0041`
- Roadmap: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`
- Keine Roadmap-Rotation: JA-027 ist fachlich nicht komplett erledigt, weil echter 100-Kandidaten-Live-Benchmark, Quellen-Nachfuellung bis 1.000 und Einzelresultat-Resume noch offen sind.
- Supertest: laut Nutzeranweisung fuer diesen Uebergang nicht auszufuehren; nicht als technischer Testnachweis werten.

## Erledigter Arbeitsschritt

JA-027.3 hat jetzt einen deterministischen, testgedeckten Batch-Metrikvertrag fuer `tools/Verify-JobAgentCompanyCandidates.ps1`.

Umgesetzt:

- Batchmanifest wird als `logs/jobagent/JA-027-batch-<run-id>.json` geschrieben.
- `run_id` wird im Summary-JSON ausgegeben.
- `batch_metrics` enthaelt:
  - `processed_total`
  - `verified_total`
  - `official_career_verified_before`
  - `official_career_verified_after`
  - `net_official_career_growth`
  - `new_official_career_company_ids`
  - `request_total`
  - `requests_per_candidate`
  - `duration_ms_p50`
  - `duration_ms_p95`
  - `net_official_career_per_minute`
- P50/P95 werden per Nearest-Rank ueber sortierte Kandidatendauern berechnet.
- Requests und Dauern zaehlen nur tatsaechlich verarbeitete eindeutige Kandidaten.
- Nettozuwachs zaehlt nur nach dem seriellen Store-Commit neu offiziell belegte Karriere-/ATS-Arbeitgeber; Domain-only, Fixture, Alias-Duplikate und Revalidierungen erhoehen ihn nicht.
- Jede Ergebniszeile enthaelt `batch_telemetry` mit Kandidaten-ID, Start/Ende, Dauer und Requestanzahl.
- Der completed-Checkpoint speichert dieselben Batch-Metriken.
- Parallele Worker fuegen ebenfalls Kandidaten-Telemetrie hinzu.

## Geaenderte Dateien

- `tools/Verify-JobAgentCompanyCandidates.ps1`
- `tests/Test-JobAgentCompanyCandidateVerification.ps1`
- `docs/company-discovery-operations.md`
- `Roadmap.md`
- `todo.state.json`
- STP-/Handoff-Dateien nach finalem Sync

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

Devserver:

- `cmd /c .\ci.cmd devserver-status` meldet Port `8500` als lauschend.

Sonar:

- `curl.exe -s http://localhost:9000/api/system/status` gab Exit `1`.
- `cmd /c .\ci.cmd sonar-start` gab Exit `1`, weil `D:\_Scripte\JobAgent\sonar.cmd` fehlt.
- SonarQube wurde daher nicht gestartet und nicht als gruen gewertet.

## Naechste Arbeit

Naechster Hotspot bleibt `JA-027.3`.

Priorisierte Aufgaben fuer den neuen Chat/Agent:

1. Produktiven 100-Kandidaten-Live-Benchmark vorbereiten und ausfuehren:
   - vorher `data/jobagent/company-candidate-verification.queue.json` und `data/jobagent/company-discovery.hints.json` gegen Eligibility pruefen;
   - sicherstellen, dass `PENDING` + `VERIFY_OFFICIAL_SITE` + faelliges `next_attempt_at` wirklich mindestens 100 unterscheidbare Kandidaten liefern;
   - wenn weniger als 100 Kandidaten faellig sind, konkrete Restursache dokumentieren, nicht als Erfolg werten.

2. Einzelresultat-Resume ergaenzen:
   - aktueller Checkpoint ist laufbezogen `running/completed`;
   - noch fehlt verlustfreies Resume je verarbeitetem Kandidat zwischen Netzwerkphase und Store-Commit;
   - Abbruch vor/nach Commit muss ohne Firmen-/URL-Verlust und ohne Doppelimport fortsetzbar sein.

3. Host-/Redirect-/ATS-Concurrency nachschaerfen:
   - aktuelle Hostbegrenzung erfolgt vor der Auswahl und anhand Initialhost;
   - JA-027 verlangt hoechstens einen gleichzeitigen Request je tatsaechlichem Host einschliesslich Redirect/ATS;
   - falls nicht in einem Slice loesbar, als klaren technischen Teil-Slice mit Testvertrag abgrenzen.

4. Quellen-Nachfuellung bis 1.000 offizielle Karriere-/ATS-Arbeitgeber planen:
   - geparkte/blockierte Quellen aus `logs/jobagent/JA-027-source-research.json` respektieren;
   - HWK nicht automatisiert importieren;
   - BioM/IHK nur mit separatem Snapshot-/Export-/API-Vertrag;
   - Stadt Freising Wirtschaft nicht als allgemeine neue Quelle nutzen, bestehende spezifische Quelle beibehalten.

5. Abschlusskriterien fuer JA-027 erst nach fachlichem Mengennachweis:
   - `logs/jobagent/JA-027-batch-<run-id>.json`
   - `logs/jobagent/JA-027-resume-<run-id>.json`
   - `logs/jobagent/JA-027-1000-career-sources.json`
   - gruenen Funktionstests
   - Roadmap-/Todo-/Handoff-Sync
   - dann erst Roadmap-Rotation.

## Risiken

- `-MaxCandidates 100` garantiert aktuell wegen Hostlimit und Eligibility nicht 100 verarbeitete Kandidaten.
- Queue kann durch vorangegangene Runs keine faelligen PENDING-Kandidaten enthalten; ein No-op darf nicht als Benchmark gelten.
- SonarQube ist lokal nicht ueber den CI-Vertrag startbar, solange `sonar.cmd` im Projektroot fehlt.
- JA-027 ist nicht abgeschlossen; JA-041/UI-001/JA-042 bleiben offen.
