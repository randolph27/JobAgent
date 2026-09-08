# Handoff latest

Stand: 2026-09-08T15:35:00+02:00

## Zustand fuer neuen Chat

- Projekt: `JobAgent`
- Active Todo: `TD-0041`
- Aktiver Roadmap-Punkt: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `in-progress`, nicht archivieren.
- Branch: `master`
- Remote: `origin/master`
- HEAD vor Abschluss dieses Chats: `c10643c6d924`
- Supertest: vom Nutzer fuer diesen Abschluss freigestellt; nicht als offener Blocker werten. Kein vollstaendiger JA-027-Supertestlauf wurde ausgefuehrt.
- Roadmap-Rotation: keine Rotation, weil kein Top-Level-Roadmap-Punkt fachlich komplett erledigt ist.

## Was in diesem Chat erledigt wurde

- JA-027 Fetch-Fehlerauswertung fuer Folge-Retries operationalisiert.
- `tools/Verify-JobAgentCompanyCandidates.ps1` schreibt in jedes `logs/jobagent/JA-027-batch-<run-id>.json` jetzt `fetch_error_summary`.
- `tools/Discover-JobAgentCompanyCandidateWebsites.ps1` schreibt in jedes `logs/jobagent/company-candidate-website-discovery-<run-id>.json` jetzt dieselbe `fetch_error_summary`.
- Einzelne Fetch-Logeintraege enthalten jetzt `exception_types` zusaetzlich zu `error_class`, `error` und `error_detail`.
- Fixture-Fetcher in beiden Tools geben `exception_types` deterministisch weiter; TLS-/DNS-/HTTP-Fehlerklassen sind damit ohne Live-Netz regressionsfaehig.
- `fetch_error_summary` enthaelt `schema_version=jobagent/fetch-error-summary/v1`, `failed_fetch_total`, `error_class_total` und `by_error_class[]` mit `error_class`, `fetch_count`, `candidate_count`, `sample_urls`, `sample_details`, `exception_types`.
- Regressionen decken `TLS_CREDENTIAL_UNAVAILABLE` inklusive `System.Net.Http.HttpRequestException` fuer Candidate-Verifikation und Website-Discovery ab.
- `docs/company-discovery-operations.md`, `Roadmap.md`, `todo.state.json`, `handoff.latest.md/json` wurden synchronisiert.
- `cmd /c .\ci.cmd stp` wurde ausgefuehrt und hat Todo-/Checkpoint-/Handoff-Artefakte aktualisiert.

## Aktueller JA-027-Stand

- Retention-Schnitt JA-027.1 ist umgesetzt: `discovery_inventory` und `discovered_urls` bleiben dauerhaft erhalten; Snapshot-Refresh loescht nicht erneut beobachtete Hints nicht mehr.
- Quelleninventar/Snapshot-Lane ist umgesetzt: 35 Registry-Quellen, 29 Snapshot-Manifesteintraege, 1.833 Hints, 1.831 Queue-Cluster, 2.312 Retention-Funde, 1.401 URL-Funde laut bisherigem Stand.
- Queue-/Retry-Grundlagen fuer JA-027.3 sind umgesetzt: due-aware Ready-Zaehler, faellige `RETRY_SCHEDULED` fuer `DISCOVER_OFFICIAL_WEBSITE` und `VERIFY_OFFICIAL_SITE`, Legacy-Datums-Toleranz, HostConcurrency fuer Redirect-/ATS-Hosts, Einzelresultat-Resume und serieller Store-Writer.
- Letzter produktiver Retrylauf vom 2026-09-08: Website-Discovery `logs/jobagent/company-candidate-website-discovery-20260908-125045.json` verarbeitete 14 Kandidaten, 0 verifiziert, 14 retryfaehig unverifiziert wegen SSL-Abruffehlern.
- Letzter Verify-Batch vom 2026-09-08: `logs/jobagent/JA-027-batch-20260908-125107.json` verarbeitete 9 Kandidaten, 27 Requests, P50 281 ms, P95 1683 ms, Nettozuwachs offizieller Karriere-/ATS-Arbeitgeber 0.
- Letzte Coverage: `logs/jobagent/company-coverage-20260908-125225.json`, `target_inventory_gate_status=passed`, `target_inventory_candidates_total=2318`, Duplicate-Groups 0, `candidate_verification_ready=0`.

## Offene Aufgaben fuer neuen Chat

1. JA-027.3 fortsetzen, sobald der naechste Retry faellig ist: ab `2026-09-10T12:51:07Z` / `2026-09-10T14:51:07+02:00`.
2. Dann ausfuehren:

~~~powershell
pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
~~~

3. Neue Logs zuerst ueber `fetch_error_summary` auswerten; bei Bedarf danach einzelne Fetches nach `error_class`, `error_detail`, `exception_types` pruefen.
4. Wenn erneut `TLS_CREDENTIAL_UNAVAILABLE` dominiert, klaeren ob es nur die Sandbox/Schannel-Umgebung betrifft; Live-Retries dann ueber die zugelassene Projekt-/CI-Umgebung ausfuehren.
5. JA-027 bleibt offen, bis ein belastbarer 100er-Live-Benchmark und mindestens 1.000 offiziell belegte Karriere-/ATS-Arbeitgeberquellen erreicht und dokumentiert sind.
6. Danach erst Roadmap-Rotation und Abschluss-Supertest/Release-Gate behandeln; gemaess aktueller Nutzeranweisung ist der diesmal nicht angefragte Supertest fuer diesen Chat erledigt.

## Weitere offene Roadmap-Punkte

- `JA-041` / `TD-0053`: IT-Leiter/Lead/Manager ueber vollstaendige Karriere- und ATS-Ergebnislisten finden; Pagination, iframe/ATS, Rollen-/Standortklassifikation offen.
- `UI-001` / `TD-0054`: vollstaendige Stellen- und Firmenansichten mit Filtern, Pagination und Viewport-Audit offen.
- `JA-042` / `TD-0055`: mindestens 1.000 Firmenkarriereseiten vollstaendig untersuchen und Wiederholung absichern; seriell nach JA-027/JA-041/UI-001.

## Verifikation in diesem Chat

- `pwsh -NoProfile -File .\tests\Test-JobAgentCompanyCandidateVerification.ps1` -> Exit 0
- `pwsh -NoProfile -File .\tests\Test-JobAgentSourceVerification.ps1` -> Exit 0
- `git -c core.pager=cat -c color.ui=false --no-pager diff --check` -> Exit 0
- `cmd /c .\ci.cmd stp` -> Exit 0
