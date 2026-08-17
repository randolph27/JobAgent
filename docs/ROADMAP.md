# Priorisierte Bootstrap-Roadmap

Annahmen: ein Entwickler mit etwa 0,7 FTE für dieses Thema, Windows als Primärplattform, drei bestehende mittelgroße Projekte, keine parallele Produktmigration durch ein zweites Team. Aufwand ist Nettoarbeitszeit; Dauer berücksichtigt Review und Beobachtungsfenster. Der Prioritätsscore von 0 bis 100 ist eine interne Kombination aus Abhängigkeit, Risiko, Nutzen und Aufwand, keine Messgröße.

## Meilenstein M1 – belastbare Einführung

1. Pilotinstallation Sound Profile
   - Abhängigkeiten: Bootstrap 1.0.0, grüner Lebenszyklustest, geprüfter Plan.
   - Aufwand: 0,5–1 PT; Dauer: 2–3 Kalendertage einschließlich Beobachtung.
   - Prioritätsscore: 96.
   - Ordnungsbegründung: validiert den gesamten Installationspfad mit der kleinsten Commandfläche vor breiter Nutzung.
   - Risiken: Android-/Sonar-Umgebung kann Diagnoseergebnisse mit Runtimefehlern vermischen.
   - Parallelisierung: Dokumentationsreview parallel möglich; keine zweite Installation gleichzeitig empfohlen.
   - Meilenstein: Audit, self-check und ein regulärer Arbeitszyklus ohne Runtime-Drift.

2. Pilot auswerten und Ubuntu Web installieren
   - Abhängigkeiten: Punkt 1 erfolgreich, Backup-/Repair-Nachweis.
   - Aufwand: 1 PT; Dauer: 3–5 Kalendertage.
   - Prioritätsscore: 92.
   - Ordnungsbegründung: prüft Node/Vite-, Seed- und Release-spezifische Pfade vor dem komplexesten Profil.
   - Risiken: bestehender Handoff-/Todo-Widerspruch erzeugt erwartete Workflow-Auditfehler.
   - Parallelisierung: Datenqualitäts-Triage kann parallel beginnen, aber ohne Schreibmigration.
   - Meilenstein: zentrale Ausführung aller regelmäßig genutzten Ubuntu-Commands bestätigt.

3. Chess installieren
   - Abhängigkeiten: Punkte 1–2, dokumentierte Behandlung gemeinsamer Probleme.
   - Aufwand: 1–2 PT; Dauer: 5–7 Kalendertage.
   - Prioritätsscore: 88.
   - Ordnungsbegründung: größte Funktions- und Historienfläche folgt nach zwei validierten Profilen.
   - Risiken: stärkste Todo-Formatdrift, zusätzliche Android-/Viewport-/Git-ACL-/Sonar-Pfade.
   - Parallelisierung: keine parallele Profilmigration; Testinventar kann vorab read-only laufen.
   - Meilenstein: ein vollständiger Build-/Verify-/Browser-Zyklus und erfolgreicher Repair-Test.

## Meilenstein M2 – Vertrauensanker und Betrieb

4. ACL- oder Signatur-Trust-Anchor einführen
   - Abhängigkeiten: Eigentümer und Betriebsidentität festgelegt.
   - Aufwand: 2–4 PT; Dauer: 1–2 Wochen einschließlich Zertifikats-/ACL-Test.
   - Prioritätsscore: 90.
   - Ordnungsbegründung: vor Mehrbenutzer- oder automatisiertem Betrieb muss Drift-Erkennung zu authentischer Freigabe werden.
   - Risiken: falsche ACL kann Publisher aussperren; Zertifikatsablauf kann Deployments blockieren.
   - Parallelisierung: Signatur-Prototyp und ACL-Test in isolierter Kopie parallel.
   - Meilenstein: unveränderbarer öffentlicher Trust Anchor und dokumentierter Key-/Recovery-Prozess.

5. Backup-Retention, Restore-Drill und Release-Verzeichnisversionierung
   - Abhängigkeiten: stabiler Trust Anchor; Speicher-/Aufbewahrungsanforderungen.
   - Aufwand: 2–3 PT; Dauer: 1 Woche.
   - Prioritätsscore: 82.
   - Ordnungsbegründung: Backups bleiben derzeit absichtlich unbegrenzt; Betrieb benötigt prüfbare Aufbewahrung und immutable Releasegenerationen.
   - Risiken: voreilige Löschung, Geheimnisse in Altbackups, ungetesteter Restore.
   - Parallelisierung: Retention-Policy und Restore-Test parallel entwerfbar.
   - Meilenstein: erfolgreicher Restore-Drill plus dokumentierte Lösch-/Quarantäneregel.

6. Portabilität Git LFS und externe Toolpfade
   - Abhängigkeiten: Profiltests auf mindestens zwei Hosts/Benutzern.
   - Aufwand: 1–2 PT; Dauer: 3–5 Tage.
   - Prioritätsscore: 68.
   - Ordnungsbegründung: hoher Wartungswert, aber kein Blocker auf dem aktuellen Host.
   - Risiken: unterschiedliche Git-Installationslayouts; Toolerkennung darf reproduzierbare Builds nicht verwässern.
   - Parallelisierung: pro Profil parallel testbar.
   - Meilenstein: keine benutzerspezifischen absoluten Laufzeitpfade außer dokumentierten Fallbacks.

## Meilenstein M3 – Workflow-Daten V2

7. Kanonischen Event-/State-Reducer und Generation-Writer implementieren
   - Abhängigkeiten: freigegebene Schemas und Konfliktregeln, Trust Anchor aus M2.
   - Aufwand: 8–12 PT; Dauer: 3–4 Wochen.
   - Prioritätsscore: 86.
   - Ordnungsbegründung: notwendige Grundlage vor jeder Historienmigration; löst atomare Veröffentlichung, Hashkette und Checkpointgrenzen.
   - Risiken: Kanonisierung und Hashberechnung müssen plattformstabil sein; Crashkonsistenz erfordert Fault-Injection-Tests.
   - Parallelisierung: Reducer, Schema-Testvektoren und Writer-Fault-Tests teilweise parallel.
   - Meilenstein: deterministischer Replay derselben Testevents mit identischem State-/Generationshash.

8. Read-only Legacy-Importer mit Konfliktreport
   - Abhängigkeiten: Punkt 7; je Projekt bestätigte Zeitzone und ID-Regeln.
   - Aufwand: 6–10 PT; Dauer: 2–4 Wochen.
   - Prioritätsscore: 84.
   - Ordnungsbegründung: importiert Fakten erst, wenn das Zielmodell stabil ist; unsichere Daten bleiben explizit unresolved.
   - Risiken: kulturabhängige Zeitstempel, doppelte Roadmap-IDs, duale Master-Schemas, fehlende Event-IDs.
   - Parallelisierung: Extraktoren pro Projekt parallel; Konfliktregeln zentral sequenziell.
   - Meilenstein: reproduzierbarer Kandidat plus vollständiger Quellenhash-/Konfliktreport, noch ohne CURRENT-Umschaltung.

9. Projektweise V2-Migration und Beobachtung
   - Abhängigkeiten: Punkte 7–8, menschlich freigegebene Konfliktlisten.
   - Aufwand: 2–4 PT je Projekt; Dauer: 2–3 Wochen je Projekt mit Beobachtung.
   - Prioritätsscore: 78.
   - Ordnungsbegründung: irreversible semantische Entscheidung zuletzt und einzeln.
   - Risiken: verdeckte Consumer lesen weiter Legacy-Dateien; Abgleich kann bisher unbekannte Inkonsistenzen zeigen.
   - Parallelisierung: technische Vorbereitung parallel, CURRENT-Umschaltung und Abnahme sequenziell.
   - Meilenstein: V2 ist pro Projekt Source of Truth; Legacy bleibt gehashtes read-only Archiv.

## Meilenstein M4 – Dokumentationspflege

10. Projekt-README auf Einstieg reduzieren und ausführbare Referenzen generieren
    - Abhängigkeiten: stabile Runtime- und Workflow-V2-Semantik.
    - Aufwand: 2–3 PT je Projekt; Dauer: 2 Wochen gesamt.
    - Prioritätsscore: 64.
    - Ordnungsbegründung: verhindert, dass Dokumentation während vorheriger Semantikänderungen mehrfach umgebaut wird.
    - Risiken: beim Auslagern können historische Begründungen unsichtbar werden; Links und Ownership müssen klar sein.
    - Parallelisierung: pro Projekt parallel möglich.
    - Meilenstein: balancierte Markdown-Fences, klare Überschriften, keine eingebetteten ausführbaren Skriptkopien, generierter Command-Katalog.

