# JA-044 – Quellenuebergabe: Akzeptanznachweis

Stand: 2026-09-17. Status: `completed`.

Der vorhandene Firmen-, Verifikations-, Adapter- und Persistenzvertrag deckt die geforderten Uebergabefaelle bereits ab. JA-044 ergaenzt deshalb keinen parallelen Produktionspfad, sondern einen deterministischen Integrationsnachweis mit festen Firmen- und Stellenidentitaeten. Es wurden keine Produktivdaten und keine Netzwerkquellen verwendet.

## Fixture, Scope und Ergebnis

- Fixture: `tests/fixtures/jobagent/ja-044-acquisition-replay.json`
- Integrationsfunktionstest: `pwsh -NoProfile -File ./tests/Test-JobAgentJa044AcquisitionReplay.ps1 -EvidencePath ./logs/jobagent/JA-044/acquisition-replay.json`
- Replay-Evidence: `logs/jobagent/JA-044/acquisition-replay.json`
- Evidence-Hash: `0d5c3b1a7c18270a88c17073f7e67255663f3c678c7cb8e3add457dbfefd6e93`

Der Fixturelauf beweist folgende Vertragsgrenzen:

| Fall | Erwartung | Ergebnis |
|---|---|---|
| Bekannte Firma, neue verifizierte Firma, Doppelhinweis | Drei stabile Firmen-IDs; Beta wird nicht doppelt angelegt | bestanden |
| Identischer Zweitlauf | `alpha-100` und `beta-200` bleiben eindeutige Stellen | bestanden |
| Timeout | `alpha-100` bleibt aktiv; Run ist `PARTIAL` | bestanden |
| Vollstaendiger Leerscan | Ausschliesslich `beta-200` wird `REMOVED` | bestanden |
| Teilscan/Budgetgrenze | `alpha-100` bleibt aktiv; Run ist `PARTIAL` | bestanden |
| Restart | Drei Firmen bleiben erhalten; keine Alpha-Dublette | bestanden |

Damit ist die fachliche Grenze belegt: Nur ein vollstaendiger erfolgreicher Scan darf die fehlende Stelle seiner Quelle als `REMOVED` bewerten. Fehler, Timeout und partielle Verarbeitung behalten bereits bekannte Stellen.

## Funktionstests

Alle geforderten Funktionstests endeten am 2026-09-17 mit Exit `0`:

- `pwsh -NoProfile -File ./tests/Test-JobAgentCompanyInventory.ps1` – 18 Faelle.
- `pwsh -NoProfile -File ./tests/Test-JobAgentSourceVerification.ps1` – 28 Faelle.
- `pwsh -NoProfile -File ./tests/Test-JobAgentSourceAdapters.ps1` – 12 Faelle.
- `pwsh -NoProfile -File ./tests/Test-JobAgentDailyRun.ps1` – 22 Faelle, darunter Wiederanlauf, Quelle mit isoliertem Fehler, Mehrquellen-Teilscan und stabile Stellen bei Profilwechsel.
- `pwsh -NoProfile -File ./tests/Test-JobAgentCoverage.ps1` – 18 Faelle.
- `pwsh -NoProfile -File ./tests/Test-JobAgentJa044AcquisitionReplay.ps1 -EvidencePath ./logs/jobagent/JA-044/acquisition-replay.json` – 6 deterministische Integrationsfaelle.
- `pwsh -NoProfile -File ./tests/Test-JobAgentTestMatrix.ps1 -WriteInventory` und danach ohne Schalter – Exit `0`; das kanonische Funktionsinventar enthaelt 579 Eintraege und die Matrix 9 Faelle.

Ein Vollsupertest wurde nicht angefragt und daher gemaess Nutzerregel als erledigt bewertet; er wurde nicht ausgefuehrt.

## Audit und Uebergabe

Der Nachweis ist eine Pipeline-, ID- und Zaehlerpruefung ohne UI-, Browser-, Emulator- oder Livecrawl-Lane. Der aktive Folgepunkt ist JA-051: gemeinsame Zeitprojektion aus `published_at`, `first_seen`, `last_seen`, Attempt-/Run-Zeiten und `company.next_scan_at`; dessen Akzeptanz muss mit festen Zeitfaellen erfolgen.
