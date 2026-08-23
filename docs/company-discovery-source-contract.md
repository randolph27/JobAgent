# JobAgent Source Registry Contract

Stand: 2026-08-23

## Ziel

Die Source Registry definiert, welche externen und lokalen Quellen fuer Firmen-Discovery genutzt werden duerfen. Sie trennt Discovery-Hinweise von offiziellen Primaerbelegen, damit keine Firma, Karrierequelle oder ATS-Quelle ohne belastbare offizielle Evidenz in den produktiven Store gelangt.

## Pflichtfelder

Jede Quelle in `data/jobagent/company-discovery.sources.json` muss diese Felder tragen:

- `source_id`: stabile ID im Format `source-registry:<slug>`.
- `source_class`: eine Klasse aus dem validierten Katalog.
- `source_url`: Einstiegspunkt der Quelle.
- `operator`: Betreiber oder verantwortliche Stelle.
- `allowed_use`: erlaubte Nutzung im JobAgent.
- `forbidden_use`: explizit verbotene Nutzung.
- `rate_limit_policy`: Abruflimit oder Abrufmodus.
- `robots_or_terms_note`: Hinweis zu Robots, Terms oder Zugriffslage.
- `expected_fields`: minimal erwartete Eingabefelder.
- `evidence_level`: fachliche Belegstaerke.
- `freshness_policy`: Aktualitaets- und Ablaufregel.
- `retention_policy`: welche Daten gespeichert werden duerfen.
- `import_mode`: erlaubter Importmodus.
- `review_required`: ob manuelle oder spaetere offizielle Pruefung zwingend ist.
- `legal_risk`: `LOW`, `MEDIUM`, `HIGH` oder `BLOCKED`.

## Quellenklassen

- `OFFICIAL_REGISTER`: Offizielle Registerportale fuer gezielte Einzelfallpruefung. Kein Bulk-Scraping, keine Karrierequelle, keine personenbezogenen Registerrollen.
- `OPEN_REGISTER_DUMP`: Nicht-amtliche Bulk-Snapshots. Nur Kandidatenhints, keine Aktivitaets- oder Vollstaendigkeitsbehauptung.
- `REGIONAL_DIRECTORY`: Regionale Wirtschafts- oder Branchenlisten. Nur Kandidatenbasis bis zur offiziellen Firmenverifikation.
- `PUBLIC_INSTITUTION_DIRECTORY`: Quellen oeffentlicher Stellen mit regionalem oder sektoralen Bezug. Nur Kandidatenbasis bis zur offiziellen Firmenverifikation.
- `JOB_BOARD_DISCOVERY`: Jobboersen wie StepStone, Arbeitsagentur oder Indeed. Immer nur volatile Arbeitgeberhinweise, nie Primaerbeleg.
- `OFFICIAL_COMPANY`: Offizielle Firmenwebsite oder Karriereseite. Primaerbeleg fuer genau diese Firma.
- `OFFICIAL_ATS`: ATS-Mandant nur mit offizieller Firmenverlinkung. Keine globale ATS-Allowlist.
- `MANUAL_REVIEW`: Lokale Review-Liste ohne externen Abruf. Keine produktive Aufnahme ohne offizielle Quelle.
- `REJECTED`: Gesperrte Quelle. Muss `import_mode=REJECT`, `evidence_level=NOT_IMPORTABLE`, `review_required=true` und `legal_risk=BLOCKED` setzen.

## Fail-Closed-Regeln

- Jobboersen muessen `source_class=JOB_BOARD_DISCOVERY`, `evidence_level=DISCOVERY_HINT` und `review_required=true` setzen.
- Register, regionale Listen und Open-Data-Dumps duerfen keine `PRIMARY_OFFICIAL`-Evidenz erzeugen.
- Nur `OFFICIAL_COMPANY` und `OFFICIAL_ATS` duerfen `PRIMARY_OFFICIAL` sein.
- Quellen ohne `allowed_use`, `forbidden_use`, `rate_limit_policy` oder `robots_or_terms_note` sind ungueltig.
- Unklare Terms, Login, Captcha, Schutzmechanismen oder fehlendes Rate-Limit blockieren Live-Abrufe.
- Produktive Firmen- oder JobSource-Aufnahme verlangt offizielle Website-, Karriere- oder ATS-Evidenz. Discovery-Hints reichen nie aus.

## Datenschutz und Speicherung

Persistiert werden nur nicht-personenbezogene Kandidaten-, Quellen- und Evidenzfelder. Registerrollen, Recruiter-Daten, Kontaktlisten, Anzeigenvolltexte und nicht erforderliche Rohseiten werden nicht gespeichert. Fuer volatile Jobboersen reicht ein minimaler Snapshot-Hash mit Suchparametern und Fund-URL.

## Validierung

Pflichtpruefungen:

```powershell
pwsh -NoProfile -File tests\Test-JobAgentCompanyInventory.ps1
pwsh -NoProfile -File tests\Test-JobAgentCoverage.ps1
```

Die Tests validieren Schema, Pflichtfelder, Quellenklassen, Jobboersen-Sperren als Primaerbeleg, Review-Pflicht, Coverage-Zaehler und responsive HTML-Artefakte.
