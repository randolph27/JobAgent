# JA-052 – Bewerbungsuebersicht: Akzeptanznachweis

Stand: 2026-09-18T12:17:22+02:00

Die Bewerbungsuebersicht nutzt ausschliesslich den lokalen `JobAgentUserState` im isolierten Browserprofil. Der Reportstore, die URL und technische Logs enthalten keine Notiz, keinen Termin und keinen Anwendungsstatus.

## Belegte Kriterien

- Die Fixture `job:remote-contract` wechselt kontrolliert von `APPLIED` zu `INTERVIEW`; die Boolean-Projektion, Korrekturhistorie, v1-Migration, Textgrenzen, Termin-CRUD, Loeschmarker, Quota-Atomaritaet sowie Export/Reload sind durch `Test-JobAgentUserState.ps1` belegt.
- Eine lokale Notizsuche nach `Rueckruf`, der Stufenfilter `INTERVIEW`, der Faelligkeitsfilter `next_7` und die Sortierung `due_then_id` liefern jeweils genau `job:remote-contract`.
- Der offene Termin `task_remote_follow_up` bleibt als `FOLLOW_UP` am lokalen Tag `2026-09-16` mit `09:00+02:00` sichtbar. Die aktive Bewerbungsansicht bleibt semantisch eindeutig selektiert.
- Die Browserinteraktion startete keine neue Ressource und erzeugte keine Browserfehler. Der Audit misst 390x844, 800x1024, 1366x768 und 1920x1080: kein horizontaler Ueberlauf, kein Control-Overlap, kein Text-Clipping und keine sichtbare Zielgroesse unter 44 CSS-Pixeln. Screenshots liegen fuer 1366 und 390 CSS-Pixel vor.

## Ausgefuehrte Funktionstests

| Befehl | Exitcode | Ergebnis |
| --- | ---: | --- |
| `pwsh -NoProfile -File ./tests/Test-JobAgentUiBrowserAudit.ps1 -ApplicationOverviewOnly` | 0 | Isolierter Stufen-, Notiz-, Termin-, Filter-, Sortier-, Netzwerk- und Screenshotfall |
| `pwsh -NoProfile -File ./tests/Test-JobAgentUserState.ps1` | 0 | Speicher-, Migrations-, Status-, Termin- und Fehlervertrag |
| `pwsh -NoProfile -File ./tests/Test-JobAgentReport.ps1` | 0 | Deterministische, sichere Reportprojektion |

Der gezielte Browsermodus vermeidet den bekannten, nicht zum JA-052-Fall gehoerenden Langlauf des Gesamtaudits und fuehrt denselben isolierten Report-, Browser- und Playwright-Adapter aus. Ein Supertest wurde gemaess Arbeitsauftrag nicht ausgefuehrt.

Artefakte: `logs/jobagent/JA-052/application-cases.json`, `doc/roadmap-screenshots/JA-052-applications-1366.png`, `doc/roadmap-screenshots/JA-052-deadlines-390.png`.
