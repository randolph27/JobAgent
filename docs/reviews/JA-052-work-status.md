# JA-052 Arbeitsstand

Stand: 2026-09-18

## Erledigte Teilbasis

- `html/jobagent/assets/jobboard-state.js` verwaltet jetzt ausschliesslich `jobagent-user-state/v2` unter `jobagent:personal:v2`.
- Ein vorhandener V1-Zustand unter `jobagent:personal:v1` wird vor der ersten V2-Schreiboperation vollstaendig validiert, in den Arbeitsspeicher migriert und danach nach V2 geschrieben. Der V1-Eintrag bleibt unveraendert als Sicherung bestehen.
- `application_stage` kennt `NONE`, `PREPARING`, `APPLIED`, `INTERVIEW`, `REJECTED` und `WITHDRAWN`. `applied` wird daraus abgeleitet; nicht beworbene Stufen haben `applied_at: null`.
- Reguläre Stufenwechsel und ausdrueckliche Korrekturen sind getrennt. Nicht reguläre Korrekturen werden mit Vorher-/Nachher-Stufe, UTC-Zeit und Begründung in `application_history` gespeichert.
- Notiz (4.000 Unicode-Codepoints), nächste Aktion (200 Unicode-Codepoints), bis zu 20 offene Termine, Terminstatus, lokales Datum, optionale Uhrzeit mit Offset sowie Loeschmarker sind im lokalen Zustand vorhanden.
- Speicherfehler lassen den vorherigen gespeicherten Zustand unverändert. Export/Import und ein feldbezogener Merge bleiben Teil der API.
- Der HTML-Report enthält den Tab `Bewerbungen`; er zeigt aktive Bewerbungsstufen, nächste Aktion und offene Termine aus dem Browserzustand.

## Nachgewiesene Funktionstests

- `pwsh -NoProfile -File .\tests\Test-JobAgentUserState.ps1` – Exit 0.
  - V1-Migration mit erhaltener Sicherung
  - Stufenprojektion und Korrekturhistorie
  - erlaubte/unzulässige Stufenwechsel
  - Unicode-Grenze der Notiz
  - Termin-CRUD, Offsetpflicht und Grenze 20/21
  - Loeschmarker gegen stille Wiederbelebung
  - Quota-Atomarität
  - Export/Reload
- `pwsh -NoProfile -File .\tests\Test-JobAgentReport.ps1` – Exit 0.
- Kein Supertest: JA-052 ist noch nicht fachlich vollständig.

## Noch offen – vor Abschluss von JA-052

1. Detail- und Listenansicht mit bedienbaren Formularen fuer Stufe, Notiz, nächste Aktion und Termin-CRUD verbinden. Der bestehende Bewerbungs-Tab ist derzeit eine Anzeige, kein Editor.
2. Rücksetzen eines fortgeschrittenen Status über den Bewerbungsstern mit sichtbarer Wirkungsbestätigung umsetzen.
3. Bewerbungsübersicht um Stufen-/Faelligkeitsfilter sowie Sortierung nach offenen Terminen, danach Job-/Task-ID erweitern.
4. Lokale Suchfunktion in Notizen, klare Speicherfehleranzeige, Fokusfolge und Formularabbruch nach Roadmap-Contract nachweisen.
5. `Test-JobAgentUiBrowserAudit.ps1` gezielt um isolierte V2-Browserprofile erweitern. Kein Supertest vor dem vollständigen JA-052-Abschluss.
6. Akzeptanznachweis und synthetische Evidence erst nach erfolgreichem Browserfunktionstest erstellen; dann Roadmap-Punkt rotieren sowie Todo/Handoff erneut synchronisieren.

## Wichtige Verträge

- Keine privaten Notizen, Termine oder Browserzustände in Reportstore, URL, Git, Logs oder Telemetrie schreiben.
- Ein Termin mit Uhrzeit braucht immer einen expliziten Offset; eine DST-Mehrdeutigkeit ohne Offset bleibt unzulässig.
- Geschlossene oder später ausgeblendete Stellen dürfen Bewerbungsdaten nicht verlieren.
- Die Roadmap verlangt sichtbare Bedienung, Browserfunktionstests und Evidence. Deshalb bleibt `JA-052` offen und `TD-0080` in Bearbeitung.
