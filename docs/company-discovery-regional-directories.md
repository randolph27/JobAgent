# Regionale Discovery-Verzeichnisse

JA-026 fuehrt eine deterministische Import-Lane fuer regionale Branchen-, Kommunal- und Arbeitgeberlisten ein.

## Vertrag

- Erlaubte Quellenklassen: `REGIONAL_DIRECTORY` und `PUBLIC_INSTITUTION_DIRECTORY`.
- Erlaubter Importmodus: `FIXTURE_OR_SNAPSHOT_ONLY`.
- Persistenz: nur Organisationsname, Gebietshinweis, Sektorhinweis, Quellseite, Beobachtungszeit, Review-Grund, Prioritaet und Hash.
- Nicht erlaubt: Kontaktfelder, E-Mail-/Telefon-Sammlung, Login-/Captcha-Abruf, Branchenbuchdaten als offizielle Karrierequelle.
- Ergebnisstatus: `REGIONAL_DISCOVERY_HINT`, `UNVERIFIED`, `official_verification_required=true`.

## Artefakte

- Modul: `src/JobAgent.RegionalDiscovery.psm1`
- CLI: `tools/Import-JobAgentRegionalDirectories.ps1`
- Standardausgabe fuer unverifizierte Hinweise: `data/jobagent/company-discovery.regional-hints.json`
- Der vorhandene verifizierte Feed `data/jobagent/company-discovery.regional.json` bleibt fuer den offiziellen Discovery-Import reserviert.
- Merge-Ziel: `data/jobagent/company-discovery.hints.json`
- Funktionstest: `pwsh -NoProfile -File tests\Test-JobAgentRegionalDiscovery.ps1`

## Parser

Unterstuetzt sind drei Snapshot-Formate:

- `table_html`: HTML-Zeilen mit `data-jobagent-regional`.
- `card_html`: HTML-Karten mit `data-jobagent-regional`.
- `json_items`: strukturierte Snapshot-Items.

Jede Quelle bleibt sekundärer Kandidatenhinweis. Produktive Firmenaufnahme und Karriere-URLs erfolgen erst in spaeteren Verifikations- und Wellen-Gates.
