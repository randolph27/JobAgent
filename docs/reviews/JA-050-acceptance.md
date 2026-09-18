# JA-050 – Akzeptanznachweis (Teilbild 1)

Stand: 2026-09-18T22:48:38+02:00

## Ausgefuehrte deterministische Fixture

Command:

```powershell
pwsh -NoProfile -File .\tests\Test-JobAgentAcceptance.ps1
```

Ergebnis: Exit 0

```json
{
  "status": "ok",
  "companies": 4,
  "historical_jobs": 4,
  "open_jobs": 3
}
```

Der Lauf prueft: Firmen- und Stellenwachstum von 3 auf 4, A1-Aktualisierung, Schliessung von A2 nach vollstaendig erfolgreichem Leerscan, Erhalt von B1 bei Quellenfehler, browserlokale Favoriten- und Bewerbungsmarkierungen, A2-Notiz mit offener Nachfassaufgabe sowie C1-Ausblendung und generationengebundene Sichtung einer gespeicherten Suche.

## Reproduzierbarkeitsbindung

| Artefakt | SHA-256 |
|---|---|
| `tests/Test-JobAgentAcceptance.ps1` | `c79c83cf255baa52187557b96342c5121f5b0d5545761d96e614186347877e03` |
| `docs/test-matrix.json` | `8e6bf67a1e6d0a1dd74f76556d11b3ccd56b8f1c1cf60485db46e83bd0dc13d9` |
| `html/jobagent/assets/jobboard-state.js` | `c7472f3a7323558f6213daf7da2e4e53f1b5c6d083cc504e2dc19cab264e3323` |

## Noch offen

JA-050 bleibt aktiv. Browser-/Viewport-, Kalender-, Export-/Import- und Lastmessungen aus Teilbild 2 und 3 sind mit diesem Teilnachweis nicht abgenommen. Der Supertest ist nicht angefragt und gilt gemaess Nutzerauftrag als erledigt; er wurde nicht ausgefuehrt.
