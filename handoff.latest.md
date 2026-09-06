# Handoff latest

Stand: 2026-09-06T12:58:03.808+02:00. Chatwechsel nach dem abgeschlossenen Planungscommit `8fb4443`. Gitfelder im JSON sind der STP-Snapshot vor dem neuen Übergabe-Commit.

## Dauerhafte Übergabe

Vollständiger Arbeitsstand, bekannte Verlustpfade, direkte Codeeinstiege, Funktionstest-Commands und nachgelagerte Aufgaben: [JA-027 – Übergabe für den nächsten Chat](docs/handoffs/2026-09-06-ja027-next-chat.md). Dieser versionierte Text bleibt erhalten, auch wenn ein späteres STP die latest-Dateien neu generiert.

## Aktueller Status

Aktiv: `TD-0041` / JA-027, `in-progress`. Nächster fachlicher Einstieg: **JA-027.1**, dauerhafte Firmen-/URL-Erfassung vor weiteren schreibenden Quellenrefreshes. Read-only-Quelleninventur aus JA-027.2 kann parallel erfolgen.

Die drei detaillierten Roadmap-Arbeitspakete sind geplant, nicht umgesetzt. Alle erfassten Firmen sowie entdeckte Website-/Jobs-/Karriere-/Stellenangebote-/ATS-URLs sollen ab Erstfund dauerhaft mit Herkunft, Status und Historie gespeichert bleiben – auch ungeprüft, ohne Website oder ohne aktuelle Stellen. Quellenrefresh, Ablauf, Fehler und leere Portale sind keine Löschgründe.

Danach JA-027.2: vorhandene/neue Jobbörsen-, Register- und Regionalquellen erschließen; unverifizierte Hinweise erhalten. Anschließend JA-027.3: unabhängige offizielle Firmen-/Karriereverifikation, echter 100er-Benchmark und 1.000 belegte Karrierearbeitgeber. Offizielle Bestätigung ist eine Verifikations-/Zählbedingung, keine Voraussetzung für dauerhafte Erfassung.

JA-041 darf anhand vorhandener belegter Quellen parallel entwickelt werden. UI-001 und JA-042 bleiben offen. 1.000 vollständige tatsächliche Stellenscans gehören zu JA-042, nicht zur Done-Definition der JA-027-Akquise. Kein aktiver Roadmap-Punkt ist abgeschlossen; keine Rotation.

## Unveränderter Datenstand

479 Firmen, 439 JobSources, 32 Quellen, 1.790 Hinweise aus 26 Quellen. Queue: 1.785 Einträge, davon 662 VERIFIED, 1.122 MANUAL_REVIEW_REQUIRED, 1 RETRY_EXHAUSTED, 0 PENDING. Fünf Hinweise ohne Queueeintrag erklären; mögliche Testdaten prüfen.

0 PENDING belegt keine Quellenerschöpfung. Hinweise, Registry und rekonstruierte Eligibility gemeinsam prüfen. Die frühere pauschale Aussage „keine nutzbaren Quellen“ ist nicht belegt. Keine neue externe Recherche, Akquise oder Änderung produktiver Dateien in diesem Abschluss.

Vorhandene Batchengine aus `4d797ee`: frühere Funktionstests sind historische Evidence; Einzelresultat-Resume, Redirect-/ATS-Hostlimits und vollständige Metriken bleiben nachzuweisen. `8fb4443` enthält die detaillierte neue Planung und wurde bereits gepusht.

## Abschluss und Verifikation

- Dauerhafte Übergabe erstellt; Todo-State/Checkpoint enthalten deren Referenz und behalten JA-027.1 als nächsten Hotspot.
- `cmd /c .\ci.cmd stp`: Exit 0.
- Konsistenz, JSON-/Dateireferenzen und Git-Diff erfolgreich geprüft; vier Codepfade und vier Testpfade vorhanden, Produktivdaten-Hashes unverändert, keine unerwarteten Dateien. Konkrete Resultate stehen in `handoff.latest.json`.
- Supertest nicht angefordert: gemäß Nutzerweisung für diesen Abschluss als erledigt/freigestellt behandelt, nicht ausgeführt und nicht als bestandener Testlauf dargestellt.
- Keine Anwendungsfunktion geändert, daher keine Anwendungs-/Browser-/Netzwerktests. Ältere Sonar-/Route-Digests sind historische STP-Eingaben.
- Stage, Commit und Push sind für die Übergabe beauftragt. Der finale saubere und synchronisierte Gitstatus wird nach Push geprüft; keine Produktivdaten zum „Bereinigen“ löschen.
