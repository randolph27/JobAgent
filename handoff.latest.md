# Handoff latest

Stand: 2026-09-18T12:01:03.210+02:00

## Aktiver Arbeitspunkt

- Active: `TD-0080` / Roadmap `JA-052`.
- Status: `in-progress`; nicht rotieren. Der geforderte Browser-Audit hat noch keinen erfolgreichen Komplettabschluss.
- Branch: `master`; Upstream: `origin/master`.
- Supertest: nicht angefragt; nach Nutzerregel für diesen Übergang nicht ausstehend.

## Umgesetzter Stand in JA-052

- Der Report erzeugt im Tab `Bewerbungen` lokale, barrierefrei bezeichnete Filter für Notiz/Aktion/Stelle, Bewerbungsstufe, Fälligkeit und Sortierung.
- Fälligkeitsfilter: alle Termine, überfällig, innerhalb von sieben Tagen, mit offenem Termin und ohne offenen Termin. Referenz ist ausschließlich `reference_time` des angezeigten Reports; es gibt keinen Browserzeit- oder Netzwerkkontakt.
- Sortierung: offenes lokales Datum, danach Task-ID, danach Stellen-ID; alternativ Status/Stellen-ID oder Stellen-ID.
- Die Karten zeigen Status, nächste Aktion, Notiz sowie offene Termine mit lokalem Datum und optionaler Uhrzeit mit Offset.
- Der Wechsel zurück zu Stellen oder Firmen blendet den Bewerbungs-Tab aus und setzt dessen `aria-selected` auf `false`. Vorher konnten Stellen- und Bewerbungs-Panel gleichzeitig sichtbar sein.
- Die Persistenz bleibt ausschließlich `localStorage` über `JobAgentUserState`; Reportstore, URL und technische Logs bekommen keine persönlichen Daten.

## Teststand

- Grün: `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1`.
- Grün: `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1`.
- `tests\Test-JobAgentUiBrowserAudit.ps1` enthält einen neuen isolierten Fall `ja052_application_overview_local_note_stage_due_and_sort_filters`. Er erzeugt eine lokale Interview-Stufe, Notiz, Folgeaufgabe und Termin mit Offset; prüft Notizsuche, Stufen- und Fälligkeitsfilter, Sortierung sowie keine während der Filteraktion gestartete Ressource.
- Der vollständige `Test-JobAgentUiBrowserAudit.ps1`-Lauf blieb nach dem neuen Fall in einem bestehenden langen Playwright-Abschnitt ohne weitere Artefaktfortschreibung hängen und wurde kontrolliert beendet. Er ist deshalb `not-run`/nicht grün, nicht als Fehler der neuen Assertions zu werten. Für die Fortsetzung zuerst denselben Test erneut in isoliertem Hintergrundprofil starten und bei erneutem Hängen den letzten Playwright-CLI-Aufruf unter `logs/jobagent/QA-004/<run-id>/playwright/.playwright-cli/` bestimmen.
- Der Audit-Helper berücksichtigt nun geschlossene `<details>`-Inhalte nicht als sichtbare Controls. Das beseitigt falsche mobile Overlap-Befunde aus nicht dargestellten Bewerbungseditoren. Der A11y-Helper akzeptiert sichtbare `aria-label`-Beschriftungen zusätzlich zu nativen Labels.

## Nächste konkrete Schritte

1. `./ci.cmd devserver-status` prüfen; falls nicht erreichbar, ausschließlich über `./ci.cmd devserver-start` im Hintergrund starten.
2. `pwsh -NoProfile -File .\tests\Test-JobAgentUiBrowserAudit.ps1` im isolierten Hintergrundprofil ausführen. Kein Supertest erforderlich.
3. Bei Hängen: letzten CLI-Befehl und zugehörige Momentaufnahme im aktuellen `logs/jobagent/QA-004/<run-id>/playwright/.playwright-cli/` vergleichen; nur den betroffenen Browserpfad gezielt ausführen. Keine generische Lockerung von Assertions.
4. Nach grünem Browser-Audit: `docs/reviews/JA-052-acceptance.md` und `logs/jobagent/JA-052/application-cases.json` mit Testbefehl, Exitcode, Reportreferenz, Fixture-IDs und lokalen Filterergebnissen erzeugen; dann Roadmap/Todo/Checkpoint synchronisieren und `JA-052` erst bei vollständig belegten Akzeptanzkriterien rotieren.
5. Danach `TD-0081` / `JA-053` beginnen: fachliche Stellenchronik ausschließlich aus Snapshots und Change-Events; technische Quellenfehler dürfen kein Stellenende behaupten.

## Unabhängige offene Punkte

- `TD-0085` bleibt offen. STP meldet bekannte Route-Verstöße ausschließlich in gebündelten Sonar-JRE-Lizenzdateien unter `.ci/tools/sonar/...`; keine Änderung ohne eigene CI-Driftanalyse.
- Reihenfolge nach JA-052: `JA-053`, `JA-055`, `JA-049`, `JA-054`, `JA-056`, `JA-050`.
