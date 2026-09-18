# Handoff latest

Stand: 2026-09-18T08:39:57.589+02:00

## Zustand

- Active: ``
- Status: `open`
- Ziel: Keine aktive Roadmap-Aufgabe.
- Branch: `master`
- HEAD: `c6c0f0d261a2`
- Upstream: `origin/master`
- Ahead/Behind: `0/0`
- Worktree: `dirty`
- Route: `False`

## Versionierte Aenderungen

- `handoff.latest.md`
- `src/JobAgent.Report.psm1`
- `tests/Test-JobAgentUiBrowserAudit.ps1`
- `todo.history.digest.json`
- `todo.master.index.json`

## Verifikation

- `ps: pwsh -NoProfile -File .\tests\Test-JobAgentCiContracts.ps1` -> Exit `0`

## Naechster Anker

M2 – Stellenboersen-Oberflaeche: JA-048 Stellendetails und zwei eindeutig bedienbare Sterne integrieren #comment: Jede Stelle muss vollstaendig pruefbar, separat merkbar und manuell als schon beworben markierbar sein.

## Fachlicher Uebergabestand JA-048

- `src/JobAgent.Report.psm1` hat zwei getrennte Schalter fuer Favorit und Bewerbungsmarkierung auf Karte und Detailansicht. Beide nutzen den browserlokalen v1-Store, haben eigene Texte und `aria-pressed`, verhindern Navigation und zeigen ein Speicherergebnis.
- Ein Jobtitel oeffnet die lokale Detailansicht via `#job=<job_id>` und behaelt Filterzustand. Die Detailansicht zeigt Firma, Ort, Arbeitsbedingungen, Zeit-/Aktualitaetsdaten, Beschreibung, Anforderungen sowie getrennte Original-/Firmenlinks. Der Rueckweg setzt den Fokus auf den zuvor geoeffneten Titel.
- Neu in diesem Commit: Unbekannte `job`-IDs bleiben im Hash und rendern den sicheren Leerzustand `Stellendetail nicht verfuegbar`; die Ruecktaste entfernt nur `job`. Kein Fallback auf einen beliebigen aktiven Job.
- Neu in diesem Commit: Markierte Jobs, die im aktiven offenen Report fehlen, bleiben als lokale Referenz erhalten. Bei Favoriten- oder Bewerbungsfilter erscheinen sie getrennt als historische Karten mit dem Status `Nicht mehr im aktuellen offenen Stellenbestand`; sie zaehlen nicht zum offenen Bestand und beide Markierungen bleiben getrennt bedienbar.

## Tests und offene Nachweise

- Gruen: `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1`.
- Gruen: `git diff --check`.
- `tests/Test-JobAgentUiBrowserAudit.ps1` enthaelt neue Assertions fuer unbekannte Detail-ID, Hash-Erhalt/Rueckkehr und einen historischen zugleich favorisierten/beworbenen Job.
- Der vollstaendige Browser- und Viewportlauf ist noch nicht als Erfolg belegt. Zwei manuell gestartete Browserlaeufe hinterliessen nicht terminierende Child-Prozesse und wurden beendet; diese Laeufe gelten nicht als Testresultat. Vor Wiederholung `./ci.cmd devserver-status` verwenden, den vorhandenen Listener auf 8500 nutzen und nur eine Testinstanz starten.
- Noch ergaenzen: Browserassertions fuer die unabhängigen Karten-/Detail-Schalter, ihre gegenseitige Nichtbeeinflussung und den Rueckfokus. Danach `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` und `pwsh -NoProfile -File .\tests\Test-JobAgentHtmlViewportAudit.ps1` ausfuehren.
- JA-048/TD-0076 bleibt offen und wird nicht rotiert. Gemäss Nutzerauftrag ist kein Supertest erforderlich.

## Bekannte externe Einschränkung

- Der Route-Check meldet elf vorbestehende Funde ausschliesslich in unveraenderten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/**/jre/legal/**`. Diese Dateien nicht loeschen oder umschreiben; TD-0085 behandelt die CI-Abweichung separat.
