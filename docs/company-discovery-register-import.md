# Register-Discovery-Import

Registerdaten sind im JobAgent nur Kandidaten-Hinweise. Sie belegen keine aktive Firma, keine Karrierequelle und keine Bewerbungsmöglichkeit.

## Vertrag

- Erlaubte Bulk-Quelle ist nur `source-registry:offeneregister_dump` mit `source_class=OPEN_REGISTER_DUMP`, `import_mode=BULK_SNAPSHOT`, `evidence_level=DISCOVERY_HINT` und `review_required=true`.
- Offizielle Portale wie Unternehmensregister und Handelsregister bleiben auf gezielte Einzelfallprüfung begrenzt.
- Persistiert werden nur nicht-personenbezogene Firmenfelder: Name, Stadt, Registergericht, Registernummer, Rechtsform, Snapshot-Metadaten, Zielgebiet, Confidence, Reviewstatus und Dedupe-Keys.
- Nicht persistiert werden Geschäftsführungs-, Gesellschafter-, Bonitäts-, Compliance- oder Kontaktdaten.
- Produktive `companies` und `job_sources` bleiben unverändert. Jeder Register-Hint setzt `official_verification_required=true`.

## Nutzung

```powershell
pwsh -NoProfile -File tools\Import-JobAgentRegisterCandidates.ps1 `
  -InputPath tests\fixtures\jobagent\register-discovery\offeneregister-sample.jsonl `
  -SnapshotId offeneregister-sample-2026-08 `
  -SnapshotDate 2026-08-01T00:00:00Z
```

Output:

- `data/jobagent/company-discovery.register.json`
- Merge in `data/jobagent/company-discovery.hints.json`
- Log `logs/jobagent/company-discovery-register-import-*.json`

## Akzeptanz

```powershell
pwsh -NoProfile -File tests\Test-JobAgentRegisterDiscovery.ps1
```

Der Test deckt JSONL/CSV, Zielgebietsfilter, Dubletten, unvollständige Daten, stale/future Snapshots, Source-Registry-Fail-Closed und die Sperre personenbezogener Registerrollen ab.
