# JA-027 Handoff: TLS-Blocker und Wiederaufnahme

Stand: 2026-09-08T20:14:12.857+02:00

## Aktiver Stand

- Aktives Todo: `TD-0041`
- Roadmap-Punkt: `JA-027 Firmenakquise als wiederaufnehmbaren Batch bis mindestens 1.000 offizielle Karrierequellen ausbauen`
- Status: `blocked` fuer den naechsten produktiven JA-027.3-Live-Schritt
- Branch/HEAD vor diesem Handoff: `master` / `4a5131d57e6b`
- Upstream: `origin/master`, Ahead/Behind vor finalem Commit: `0/0`
- Roadmap-Rotation: keine Rotation; `JA-027` ist fachlich nicht komplett abgeschlossen.

## Kurzlage fuer den naechsten Chat

JA-027.1/.2 und grosse Teile von JA-027.3 sind implementiert, aber der produktive Live-Benchmark kann aktuell nicht belastbar fortgesetzt werden. Der dominante Live-Fehler liegt nicht in Queue-/Retry-Logik, sondern im lokalen Windows-TLS-Fetchpfad: PowerShell/.NET und `curl.exe` scheitern auf denselben HTTPS-Beispiel-URLs mit Schannel `SEC_E_NO_CREDENTIALS`.

Der naechste Agent soll deshalb nicht sofort Retry-Kandidaten verbrauchen. Zuerst muss die lokale TLS-/Schannel-Umgebung repariert oder ein kontrollierter alternativer Fetchpfad entschieden und getestet werden.

## Umgesetzter Stand aus JA-027

- Dauerhafte Retention ist umgesetzt: `discovery_inventory` und `discovered_urls` im Store-Schema, Import-/Snapshot-/Name-only-Hint-Retention, Migration ohne Firmen-/JobSource-Verlust.
- Quelleninventur und Queue-Reconciliation sind umgesetzt: 35 Registry-Quellen, 29 Snapshot-Manifeste, 1.833 Hints, 1.831 Queue-Cluster, 2.312 Retention-Funde, 1.401 URL-Funde.
- JA-027.3 Batchmetrikvertrag ist umgesetzt: `tools/Verify-JobAgentCompanyCandidates.ps1` schreibt `JA-027-batch-<run-id>.json` mit Kandidaten-Telemetrie, Requests, P50/P95, Nettozuwachs und Checkpoint-Metriken.
- Einzelresultat-Resume ist umgesetzt: Resultate werden vor Store-Commit atomar checkpointed; Folgelaeufe laden offene `running`-Checkpoints und dokumentieren `JA-027-resume-<run-id>.json`.
- Hostlimit ist umgesetzt: `HostConcurrency` wird bis zur HTTP-Policy durchgereicht; Redirect-/ATS-Hosts werden per Host-Semaphore begrenzt.
- Retry-Wiederaufnahme ist umgesetzt: `RETRY_SCHEDULED` fuer `DISCOVER_OFFICIAL_WEBSITE` und `VERIFY_OFFICIAL_SITE` bleibt faelligkeitsgesteuert retryfaehig; Legacy-Datumswerte werden tolerant gelesen.
- Coverage-Ready-Semantik ist umgesetzt: `candidate_verification_ready` und Queue-`ready_total` nutzen dieselbe Faelligkeitslogik wie die eigentliche Kandidatenauswahl.
- Coverage-Gate-Konflikt fuer bestaetigte Discovery-Hints ist geschlossen: verifizierte `CAREER_URL_VERIFIED`/`COMPANY_DOMAIN_VERIFIED`/`OFFICIAL_ATS_VERIFIED`-Firmen werden nicht mehr als manuelle Review-Konflikte behandelt.
- Strukturierte Fetch-Diagnostik ist umgesetzt: Fetches enthalten `error_class`, `error_detail`, `exception_types`; Batch- und Website-Discovery-Manifeste enthalten `fetch_error_summary`.
- `tools/Inspect-JobAgentFetchErrors.ps1` und `tools/Test-JobAgentFetchEnvironment.ps1` sind vorhanden und funktional getestet.

## Letzte belastbare Live-/Evidence-Artefakte

- `logs/jobagent/JA-027-retention-migration.json`
- `logs/jobagent/JA-027-retention-regression.json`
- `logs/jobagent/JA-027-source-inventory.json`
- `logs/jobagent/company-candidate-website-discovery-20260907-111545.json`
- `logs/jobagent/JA-027-batch-20260907-111932.json`
- `logs/jobagent/company-coverage-20260908-125225.json`
- `logs/jobagent/JA-027-fetch-error-inspection-20260908-153700.json`
- `logs/jobagent/JA-027-fetch-environment-20260908-174432.json`
- `logs/jobagent/JA-027-fetch-environment-20260908-181311.json`

## Aktuelle Messwerte und Blocker

Letzter produktiver Retrylauf:

- Website-Discovery `logs/jobagent/company-candidate-website-discovery-20260908-125045.json`: 14 Kandidaten verarbeitet, 0 verifiziert, 14 retryfaehig unverifiziert wegen SSL-Abruffehlern.
- Verify-Batch `logs/jobagent/JA-027-batch-20260908-125107.json`: 9 Kandidaten verarbeitet, 27 Requests, P50 281 ms, P95 1683 ms, Nettozuwachs offizieller Karriere-/ATS-Arbeitgeber 0.
- Naechster Retry aus diesem Lauf: `2026-09-10T12:51:07Z` / `2026-09-10T14:51:07+02:00`.

Fetch-Fehlerinspektion:

- `logs/jobagent/JA-027-fetch-error-inspection-20260908-153700.json`
- 143 fehlgeschlagene Fetches ueber die letzten relevanten Logs.
- Dominant: `TLS_HANDSHAKE_FAILED`, 91/143 = 63,64 %.
- Status: `environment_tls_check_required`.

Fetch-Environment-Probes:

- `logs/jobagent/JA-027-fetch-environment-20260908-174432.json`
- `logs/jobagent/JA-027-fetch-environment-20260908-181311.json`
- Beide bestaetigen: `status=all_probe_clients_failed`.
- Geprueft wurden fuenf TLS-Beispiel-URLs aus dem Inspection-Log.
- PowerShell/.NET: `The SSL connection could not be established ... Im Sicherheitspaket sind keine Anmeldeinformationen verfuegbar.`
- `curl.exe`: `schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS`.

## Verifikation in diesem Abschluss

Ausgefuehrt:

```powershell
pwsh -NoProfile -File .\tools\Test-JobAgentFetchEnvironment.ps1 -ProjectRoot . -MaxUrls 5 -TimeoutSeconds 12
```

Ergebnis:

- Exitcode: `0`
- Fachstatus: `all_probe_clients_failed`
- Output: `logs/jobagent/JA-027-fetch-environment-20260908-181311.json`

STP wurde anschliessend ausgefuehrt:

```powershell
.\ci.cmd stp
```

Supertest wurde in diesem Chat nicht angefragt; gemaess Nutzeranweisung gilt ein nicht angefragter Supertest fuer diesen Abschluss als erledigt. Es wurde kein Supertest ausgefuehrt.

## Offene Aufgaben in fachlicher Reihenfolge

1. TLS-/Fetch-Umgebung reparieren oder kontrollierten alternativen Fetchpfad festlegen.
   - Abhaengigkeit: lokale Windows-Schannel-/Credential-Konfiguration oder bewusst implementierter alternativer Client.
   - Erfolgskriterium: `tools/Test-JobAgentFetchEnvironment.ps1` meldet mindestens `dotnet_fetch_available` oder `dotnet_fetch_fails_but_curl_succeeds`.
   - Risiko: erneutes Verbrauchen von Retry-Kandidaten ohne funktionierenden Fetchpfad erzeugt nur weitere technische Retries ohne Akquisefortschritt.

2. Nach erfolgreichem Probe-Lauf faellige Website-Discovery-Retries ausfuehren.
   - Command:

   ```powershell
   pwsh -NoProfile -File .\tools\Discover-JobAgentCompanyCandidateWebsites.ps1 -ProjectRoot . -MaxCandidates 100
   ```

   - Abhaengigkeit: funktionierender HTTPS-Fetch.
   - Erfolgskriterium: neue offizielle Firmenwebsites oder begruendete Review-/Retry-Ergebnisse; kein dominanter `SEC_E_NO_CREDENTIALS`-Fehler.

3. Danach faellige Candidate-Verification-Retries ausfuehren.
   - Command:

   ```powershell
   pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
   ```

   - Abhaengigkeit: Schritt 2 und faellige Queue-Eintraege.
   - Erfolgskriterium: echter 100er-Benchmark mit bearbeiteten Kandidaten, Request-/Quantilmetriken und verwertbarem Nettozuwachs oder belastbarer Restursache.

4. Coverage neu messen.
   - Command:

   ```powershell
   pwsh -NoProfile -File .\tools\Measure-JobAgentCompanyCoverage.ps1 -ProjectRoot .
   ```

   - Erfolgskriterium: getrennte Zahlen fuer Firmenbestand, offizielle Quellen, Ready-Kandidaten und Zielinventar-Gate; keine widerspruechlichen Discovery-Hint-Konflikte.

5. JA-027 erst abschliessen/rotieren, wenn alle fachlichen Done-Kriterien belegt sind.
   - Noch offen: 100er-Live-Benchmark, 1.000 belegte offizielle Karriere-/ATS-Arbeitgeberquellen, Abschluss-Evidence `JA-027-1000-career-sources.json`.
   - Bis dahin bleibt `TD-0041` `in-progress` beziehungsweise bei TLS-Blockade fachlich blockiert.

## No-Gos fuer den naechsten Agent

- Keine Roadmap-Rotation fuer `JA-027`, solange 100er-Benchmark und 1.000 offizielle Karrierequellen fehlen.
- Keine Retry-Kandidaten erneut verbrauchen, solange `Test-JobAgentFetchEnvironment.ps1` weiter `all_probe_clients_failed` meldet.
- Keine Firmen-/URL-Funde loeschen, nur weil eine Quelle temporaer nicht erreichbar ist.
- Keine Aggregatoren als offizielle Karrierequelle zaehlen.
- Keine 1.000 aus Kandidaten-, Domain-, Queue- oder Snapshotzahlen ableiten; nur belegte offizielle Karriere-/ATS-Arbeitgeberquellen zaehlen.

## Empfohlener Einstieg fuer den neuen Chat

```powershell
pwsh -NoProfile -File .\tools\Test-JobAgentFetchEnvironment.ps1 -ProjectRoot . -MaxUrls 5 -TimeoutSeconds 12
```

Wenn der Status weiter `all_probe_clients_failed` ist, bleibt JA-027.3 blockiert. Dann zuerst Windows-Schannel/TLS beziehungsweise einen explizit kontrollierten Fetchadapter behandeln. Wenn mindestens ein Client erfolgreich ist, mit den Website-Discovery- und Candidate-Verification-Retrycommands oben fortfahren.
