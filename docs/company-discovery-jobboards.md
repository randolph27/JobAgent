# Jobboersen-Discovery

Stand: 2026-08-23

## Vertrag

Jobboersen liefern im JobAgent nur volatile Arbeitgeber-Hinweise. Ein Treffer aus StepStone, Arbeitsagentur, Indeed oder einer spaeter freigegebenen Plattform darf keine produktive Firma, keine JobSource und keinen offiziellen Bewerbungslink erzeugen. Produktive Aufnahme verlangt danach eine offizielle Firmenwebsite, Karriere-URL oder belegten ATS-Mandanten.

## Importmodus

- Freigegeben sind nur Quellen aus `data/jobagent/company-discovery.sources.json` mit `source_class=JOB_BOARD_DISCOVERY`, `evidence_level=DISCOVERY_HINT`, `review_required=true` und nicht blockiertem Importmodus.
- `FIXTURE_OR_SNAPSHOT_ONLY` verarbeitet gespeicherte, minimale Snapshots.
- `MANUAL_REVIEW_ONLY` und `REJECT` sind fail-closed.
- Live-Abrufe sind ohne eigene dokumentierte Freigabe, Robots-/Terms-Pruefung und Rate-Limit nicht Bestandteil der Funktionstests.

## Persistierte Felder

Persistiert werden nur:

- Arbeitgebername, normalisierter Name, Jobtitel, Ort und Plattform.
- Suchparameter, Seitennummer, Abrufzeitpunkt und Posting-URL als Fundstelle.
- `source_record_hash` und `evidence_snippet_hash` statt Anzeigenvolltext.
- `confidence_score`, `is_staffing_agency`, `official_verification_required=true`, `verification_status=UNVERIFIED`.

Nicht gespeichert werden Anzeigenvolltexte, Recruiter-/Kontaktdaten, Login-Daten, Captcha-Zustaende oder personenbezogene Informationen.

## Bedienung

```powershell
pwsh -NoProfile -File tools\Import-JobAgentJobBoardEmployers.ps1 `
  -SnapshotPath tests\fixtures\jobagent\jobboard-discovery\stepstone-muenchen-snapshot.json
```

Das Tool schreibt:

- `data/jobagent/company-discovery.jobboards.json`
- `data/jobagent/company-discovery.hints.json`
- `logs/jobagent/company-discovery-jobboards-import-*.json`

## Validierung

```powershell
pwsh -NoProfile -File tests\Test-JobAgentJobBoardDiscovery.ps1
```

Der Funktionstest deckt Arbeitgeberextraktion, Pagination-Grenzen, Rate-Limit-/Source-Policy, Personaldienstleister-Markierung, Dubletten, leere Ergebnisse, blockierte Plattformen und die Sperre gegen JobSource-Seiteneffekte ab.
