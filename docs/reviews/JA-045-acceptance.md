# JA-045 Abnahme – browserlokale Markierungen v1

Stand: 2026-09-17

## Ergebnis

`html/jobagent/assets/jobboard-state.js` stellt den DOM-unabhaengigen, browserlokalen Zustand mit dem festen Key `jobagent:personal:v1` bereit. Das v1-Schema trennt `favorite`, `applied`, `favorite_updated_at`, `applied_updated_at` und `applied_at` pro stabiler `job_id`.

- Ein manuelles `applied=true` setzt `applied_at`; `applied=false` leert ausschliesslich `applied_at`. Wiederholte gleiche Bedienwerte veraendern keine Zeitstempel.
- Lesen vor jedem Schreiben, Validierung vor Import, Vorschau vor Import und feldweiser Merge nach juengerem UTC-Zeitstempel sind implementiert. Gleichzeitige Read/Modify/Write-Schreibvorgaenge bleiben eine dokumentierte localStorage-Grenze; es gibt keine behauptete Mehrtabtransaktion.
- Blockierter Speicher, Schreibquota, korruptes JSON und unbekannte Schema-Version liefern einen nicht persistenten Status und ueberschreiben den Originalwert nicht. Export/Import arbeitet ausschliesslich benutzerinitiiert ueber die API; es gibt keine Konten, Cloud, HTTP-Schreibschnittstelle oder automatische Bewerbung.
- `storage`-Events aktualisieren andere Tabs. Referenzfelder fuer Titel, Firma und offiziellen Link bleiben lokaler, markierter Kontext auch fuer entfernte Stellen.

## Nachweis

| Test | Ergebnis |
|---|---|
| `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` | Exit 0: Schema, vier Zustaende, getrennte Zeiten, Idempotenz, neue ID, Speicherfehler, Importvorschau/-merge, Export/Reload und Tab-Synchronisation |
| `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` | Exit 0: Report bleibt deterministisch; das State-Modul wird selbstenthalten eingebunden |
| `pwsh -NoProfile -File .\tests\Test-JobAgentTestMatrix.ps1` | Exit 0: Testmatrix und kanonisches Inventar enthalten den neuen Funktionstest |
| `.\ci.cmd supertest` | Exit 0: 30/30 bestanden, 0 fehlgeschlagen, 0 blockiert, 0 nicht ausgefuehrt; `logs/jobagent/QA-006/20260917T173836924Z/summary.json` |

Die Bedienoberflaeche fuer die beiden Sterne folgt erst in JA-048. Deshalb wurden keine funktionslosen Stern-Controls hinzugefuegt und kein visueller Browser-/Emulator-Audit als JA-045-Nachweis ausgegeben.
