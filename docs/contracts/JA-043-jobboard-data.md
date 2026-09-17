# JA-043 Datenvertrag fuer den Stellenbestand

Stand: 2026-09-17. Der Vertrag gilt fuer `jobagent/v1` ohne Neuvergabe bestehender IDs.

## Identitaet und Quellen

| Feld/Regel | Persistenz | Projektion | Regel |
|---|---|---|---|
| Stelle | `jobs.job_id` | `sections.active_jobs[].job_id` | Eine Karte pro stabiler ID; ATS-/externe ID oder kanonische offizielle URL bleiben die vorhandene Deduplikationsbasis. Titel plus Firma ist keine ID. |
| Firma | `jobs.company_id` | `company`, `company_id` | Branche kommt ausschliesslich aus `companies.industry`; Firmensitz ersetzt keinen Stellenort. |
| Quelle | `jobs.source_id`, `job_sources` | `official_url`, `provider_link` | Eine gueltige offizielle Detail-URL ist Pflicht. Karriereuebersicht und Stellen-URL bleiben getrennt. |
| Mehrorte | `jobs.location` | `location`, `area_facets` | Ein Job bleibt eine ID. Weitere belegte Orte sind keine Erlaubnis, eine Duplikat-ID zu erzeugen. |

## Feldmatrix und fehlende Angaben

| Fachfeld | Quelle | Persistenz | Report/Filter | Fehlwert |
|---|---|---|---|---|
| Titel, Beschreibung, Anforderungen | offizielle Detailquelle | `title`, `description`, `requirements` | Karte/Details/Freitext | `UNKNOWN` / „Keine Angabe“ |
| Berufsgruppe | Klassifikation | `classification`, `priority` | Profilansicht | `UNKNOWN`; Heuristik bleibt in den Klassifikationsgründen nachvollziehbar |
| Stellenort/Gebiet | Stellenquelle | `location`, `regional_scope` | Gebietsfacetten | `UNKNOWN`; kein Firmensitz-Fallback |
| Arbeitsmodell, Anstellungsart, Arbeitszeit | Stellenquelle | `work_model`, `employment_type`, `work_time` | jeweilige Filter | `UNKNOWN`; niemals Remote, Teilzeit oder Vollzeit ableiten |
| Gehalt | Stellenquelle | `salary` | Details | `UNKNOWN`; niemals `0 EUR` |
| Publikation | Stellenquelle | optionales `published_at` | Alter mit `published_at`, sonst `first_seen` | `UNKNOWN`; keine Datumsschätzung |
| Sichtungszeiten | erfolgreicher Adapterlauf | `first_seen`, `last_seen` | Karte/Details | `UNKNOWN`; Fehler und PARTIAL aktualisieren `last_seen` nicht |
| Lebenszyklus | Statusmaschine | `status`, `changed_at` | aktive/exkludierte Mengen | `NEW`, `ACTIVE`, `UPDATED`, `CLOSED`, `REMOVED`, `INVALID` |

`published_at` ist additiv und optional. Die Persistenzmigration ergänzt keinen erfundenen Altwert; vorhandene Stores werden unverändert gelesen und geschrieben. Ein valider Quellenzeitpunkt wird bei neuer oder aktualisierter Rohstelle nach UTC normalisiert. Fehlt er in einem Folgelauf, bleibt der vorhandene Wert erhalten.

## Verfuegbarkeit

Die feste `reference_time` eines Reports ist dessen `generated_at`. Der konfigurierbare Planungsdefault betraegt 7 x 24 Stunden und wird inklusiv ausgewertet.

| Projektion | Bedingung |
|---|---|
| `CURRENT` | letzte erfolgreiche Quellenbestaetigung derselben `source_id` liegt bei oder vor `reference_time` und hoechstens 604800 Sekunden zurueck |
| `CHECK_PENDING` | erfolgreiche Quellenbestaetigung liegt mehr als 604800 Sekunden zurueck |
| `FRESHNESS_UNKNOWN` | keine erfolgreiche Quellenbestaetigung mit gueltigem Zeitpunkt vor der Reportreferenz |

Als offene Bestandsmenge gelten nur `NEW`, `ACTIVE` und `UPDATED`; `CLOSED`, `REMOVED` und `INVALID` werden getrennt als ausgeschlossen gezaehlt. Ein fehlgeschlagener oder partieller Abruf ist keine Schliessung und erneuert weder die Quellenbestaetigung noch `last_seen`. Ueberfaellige offene Stellen bleiben sichtbar und werden als „Pruefung ausstehend“ gekennzeichnet.

## Invarianten

- Ein Wiederholungslauf mit gleicher Generation ist deterministisch.
- Fehlende Werte werden nicht als fachliche Werte interpretiert.
- Private Markierungen gehoeren nicht in diesen Datenvertrag; sie folgen erst JA-045.
- Der Vertrag schreibt keine Produktionsdaten um und fuehrt keinen Liveabruf aus.
