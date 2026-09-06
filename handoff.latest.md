# Handoff latest

Stand: 2026-09-06T08:28:36.108+02:00

## Zustand

- Active: `TD-0041` / JA-027, Status `in-progress`.
- Roadmap-Punkte: keiner erfüllt; keine Rotation vorgenommen.
- Supertest: nicht angefordert; gemäß Nutzerweisung für diesen Abschluss nicht auszuführen.
- Branch: `master`; der Abschluss-Commit und Push dieses Handoffs folgen direkt nach dieser Ablage.

## Erledigter Teil-Slice

- `tools/Verify-JobAgentCompanyCandidates.ps1` trennt parallele Netzverifikation (ohne Fixture bis zu vier Worker, Hostlimit standardmäßig eins) von einem seriellen, atomaren Store-Writer mit Backup.
- Resume-Vertrag: `data/jobagent/company-candidate-verification.checkpoint.json` speichert `running`/`completed`, Kandidaten-IDs und Batchmetriken. HTTP 429 respektiert `Retry-After`; sonst gilt exponentieller Backoff.
- Funktionsprüfungen des ersten Teilslices waren grün: `Test-JobAgentRegionalDiscovery.ps1`, `Test-JobAgentSourceVerification.ps1`, `Test-JobAgentCompanyCandidateVerification.ps1`, `Test-JobAgentImportWaves.ps1` und `Test-JobAgentCompanyDedupeScale.ps1`. `git diff --check` war sauber.
- `cmd /c .\ci.cmd stp` lief am 2026-09-06T08:28:36+02:00 mit Exit 0; Todo-Index, Digest und Eventlog wurden synchronisiert.

## Aktueller harter Blocker

Der produktive 100-Kandidaten-Benchmark kann nicht gestartet werden, weil die aktuelle Kandidatenqueue keine ausführbaren Einträge enthält:

- `data/jobagent/company-candidate-verification.queue.json`: 1.785 Einträge, 662 `VERIFIED`, 1.122 `MANUAL_REVIEW_REQUIRED`, 1 `RETRY_EXHAUSTED`, 0 `PENDING`/ready.
- 1.107 Reviewfälle haben `OFFICIAL_VERIFICATION_REQUIRED`; 15 haben `NAME_MATCH_WITHOUT_STRONG_IDENTITY`.
- Die Reviewfälle enthalten keinen zulässigen offiziell belegten Website-/Domain-Hinweis. Sie dürfen nicht durch Namensraten, Aggregatoren oder unbestätigte Domains automatisch in die Verifikation überführt werden.
- `data/jobagent/store.lock` enthielt eine alte PID `4916`; der Prozess existierte bei der Prüfung nicht. Die regulären Lock-Funktionen behandeln dies kontrolliert, es ist jedoch kein Ersatz für Kandidaten.

## Nächster Arbeitsauftrag

1. Für mindestens 100 eindeutige, noch nicht verifizierte Arbeitgeber zulässige Belege beschaffen: eine offizielle Firmen-/Verzeichnisquelle mit eindeutig namenspassendem Link zur offiziellen Website oder einer belegten ATS-URL. Keine Jobbörsen, sozialen Netzwerke, Suchtreffer oder Domänenmutmaßungen als Primärbeleg verwenden.
2. Die belegten Kandidaten über `tools/Discover-JobAgentCompanyCandidateWebsites.ps1` in `VERIFY_OFFICIAL_SITE`/`PENDING` überführen; Queue, Checkpoint und Store-Backup vor dem Lauf prüfen.
3. Erst bei mindestens 100 bereiten Kandidaten den produktiven Lauf ausführen:

```powershell
pwsh -NoProfile -File .\tools\Verify-JobAgentCompanyCandidates.ps1 -ProjectRoot . -MaxCandidates 100 -WorkerCount 4 -HostConcurrency 1
```

4. Den daraus entstehenden Lauf als `logs/jobagent/JA-027-batch-*.json` auswerten bzw. ergänzen: Quellenprovenienz, netto verifizierte Arbeitgeber/min, P50/P95, Requests je Firma, Fehler-/Reviewquote und Restmenge. Ohne Messwerte keine ETA behaupten.
5. JA-027 bleibt offen, bis die Roadmap-Kriterien einschließlich 1.000 offiziell belegter Karriere-/ATS-Quellen und vollständiger Live-Scans nachweisbar sind. Anschließend erst Todo abschließen, Roadmap rotieren und STP erneut ausführen.

## Nachgelagerte Punkte

- JA-041 darf nur gegen verlässliche, offizielle Karriere-/ATS-Quellen umgesetzt werden und bleibt vom Abschluss von JA-027 abhängig.
- UI-001 und JA-042 bleiben offen; ihre Akzeptanzkriterien sind nicht nachweislich erfüllt.
