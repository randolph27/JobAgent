# QA-001 Gap-Register

Stand: 2026-09-15

Dieses Register trennt die vollständige Zuordnung aus QA-001 von einer Aussage über bereits grüne Testfälle. Alle Einträge sind geplant und blockieren die Vollabnahme ihres jeweiligen Eigentümers.

| Lücke | Eigentümer | Verbindliche Abnahme |
|---|---|---|
| Atomare Schreibfehler, Backups, Locks, Fremdpfade, Traversal sowie Identitäts- und Statusgrenzen | QA-002 | Isolierte Persistenz-, Deduplikations-, Status- und Report-Funktionstests mit expliziten Fehlerpunkten |
| Discovery, Quellenverifikation, Transportfehler, Retry, Resume, Checkpoint und CLI-Publikation | QA-003 | Kontrollierte Adapter-/Transportfixtures ohne Live-Webaufruf |
| Alle sichtbaren Such-, Filter-, Tab-, Paging-, Reset- und Linkaktionen mit Vor-/Nachzustand | QA-004 | Lokale Browserfälle mit URL, Requestliste, IDs und Datenhash |
| Geometrie, Kontrast, Rollen, Fokusreise und Tastaturpfad auf 390/800/1366/1920 | QA-005 | Messwerte, negative Rendererfixtures und gesichtete Screenshots |
| Topologische Auswahl, Childfehler, Timeout, Abbruch, Ergebnisprotokoll und Reproduzierbarkeit des Supertests | QA-006 | Isolierte Runner-Contracttests und erst danach zwei vollständige Supertestläufe |

Nicht Bestandteil von QA-001: Prozentwerte für Lines/Branches. Dafür existiert derzeit kein belastbar konfiguriertes Messverfahren; es wird keine Coverage-Zahl behauptet.
