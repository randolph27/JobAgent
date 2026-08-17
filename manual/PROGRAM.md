# JobAgent Programmvertrag

Stand: 2026-08-17

## Zweck

Der JobAgent ist ein lokaler Recherche- und Zustandsagent fuer IT-Fuehrungspositionen im Raum Muenchen und Freising. Er soll offizielle Unternehmens- und Recruitingquellen wiederholt pruefen, passende Stellen nachvollziehbar bewerten und taegliche Aenderungen ohne Dubletten ausgeben.

Der Agent darf keine Bewerbungen ausloesen, keine Kontakte anschreiben, keine personenbezogenen Bewerbungsdaten speichern und keine nicht belegten Stellen, Unternehmen, URLs, Geodaten, Gehaelter oder Verifikationsaussagen erzeugen.

## Zielprofil

### Muss

- Gesucht werden IT-Fuehrungspositionen mit substanzieller Verantwortlichkeit fuer IT-Organisation, IT-Strategie, IT-Betrieb, IT-Transformation, IT-Security, IT-Infrastruktur, Enterprise Applications, Data/AI oder vergleichbare IT-Gesamtbereiche.
- Der Standortbezug muss Muenchen, ein Umkreis von 20 km um Muenchen, Freising oder ein belastbar passendes Remote-/Hybridmodell mit Bezug zum Zielgebiet sein.
- Vollstaendigkeit ist ein langfristiges Ziel, darf aber nie behauptet werden, solange sie nicht belegt ist.
- Jede ausgegebene Stelle muss eine offizielle URL oder eine vom Unternehmen offiziell angebundene Recruiting-/ATS-URL besitzen.
- Jede Bewertung muss eine kurze, nachvollziehbare Begruendung enthalten.

### Soll

- Rollen mit Titeln wie `Head of IT`, `Director IT`, `IT Leiter`, `CIO`, `VP IT`, `Leitung Digitalisierung`, `IT Operations Lead`, `IT Security Lead` oder vergleichbaren Varianten werden bevorzugt geprueft.
- Stellen werden nach A/B/C priorisiert:
  - `A`: klare IT-Fuehrungsrolle, belastbarer Zielgebietsbezug, hohe fachliche Passung.
  - `B`: wahrscheinlich passend, aber einzelne Felder sind unklar oder nur teilweise passend.
  - `C`: fachlich relevant, aber geringe Passung, unklare Fuehrungsverantwortung oder schwacher Standortbezug.
- Fehlende optionale Angaben werden als `UNKNOWN` markiert, nicht geraten.

### Darf Nicht

- Reine Entwickler-, Administrator-, Support-, Produkt-, Projektleitungs- oder Spezialistenstellen duerfen nicht als passende IT-Fuehrungsposition ausgegeben werden, wenn keine wesentliche Fuehrungs- oder Gesamtverantwortung belegt ist.
- Jobboersen, Aggregatoren oder soziale Netzwerke duerfen nicht als Primaerbeleg gelten.
- Eine bekannte unveraenderte Stelle darf in spaeteren Laeufen nicht erneut als `NEW` ausgegeben werden.

## Zielgebiet

- Primaer: Muenchen.
- Sekundaer: 20 km Umkreis um Muenchen.
- Zusaetzlich: Freising.
- Remote oder hybrid ist nur passend, wenn die Stelle einen belastbaren Bezug zu Muenchen, Freising oder Bayern/Deutschland mit akzeptabler Praesenzanforderung hat.
- Geokoordinaten, Distanzberechnungen und Standortnormalisierung sind technische Entscheidungen und muessen vor produktiver Nutzung getestet werden.

## Quellenprioritaet

### Erlaubte Primaerquellen

- Offizielle Unternehmenswebsites.
- Offizielle Karriereseiten eines Unternehmens.
- Vom Unternehmen verlinkte oder anderweitig belegte ATS-/Recruitingplattformen.
- Offizielle Detailseiten einzelner Stellen.

### Erlaubte Sekundaerquellen

- Jobboersen, Aggregatoren, Suchmaschinen und Branchenlisten duerfen zur Entdeckung von Unternehmen oder moeglichen Stellen verwendet werden.
- Sekundaerquellen duerfen nur dann zu einem Treffer fuehren, wenn eine offizielle Quelle denselben Treffer bestaetigt.

### Ausgeschlossen

- Quellen mit Loginpflicht, Captcha, Paywall oder technischen Schutzmechanismen duerfen nicht umgangen werden.
- Robots-, ToS- oder Rate-Limit-Grenzen duerfen nicht absichtlich verletzt werden.
- Nicht belegbare Angaben aus Snippets, Caches oder KI-Ausgaben duerfen nicht als Fakten gespeichert werden.

## Persistenzpflicht

Der JobAgent muss Zustand dauerhaft und lokal unterhalb des Projektverzeichnisses speichern. Fachliche Daten duerfen nicht mit CI-/Bootstrap-Todo-Dateien vermischt werden.

Mindestens zu speichern sind:

- Unternehmen mit stabiler `company_id`, kanonischem Namen, Domain, offizieller Website, Karriere-URL, Aliasnamen, Standortbezug, ATS-Hinweisen, Scanstatus und Zeitstempeln.
- Stellen mit stabiler `job_id`, `company_id`, offizieller URL, externer Job-/ATS-ID, Titel, Standort, Arbeitsmodell, Beschaeftigungsart, Status, `first_seen`, `last_seen`, `changed_at`, Klassifikation, Prioritaet und Quellnachweisen.
- Scanlaeufe mit `scan_run_id`, Start-/Endzeit, Status, Fehlern, untersuchten Firmen und erzeugten Artefakten.
- Scanversuche je Firma oder Quelle mit Fehlerklasse, HTTP-/Adapterstatus, Retry-Empfehlung und Zeitstempel.
- Schnappschuesse und Aenderungsereignisse fuer Statuswechsel, Inhaltsaenderungen, neue Stellen und entfernte Stellen.

Schreibvorgaenge muessen atomar oder nachvollziehbar wiederherstellbar sein. Migrationen muessen versioniert, getestet und mit Backup ausgefuehrt werden.

## Statusmodell

Zulaessige fachliche Jobstatus:

- `NEW`: erstmals offiziell erkannte und fachlich relevante Stelle.
- `ACTIVE`: bekannte Stelle, erneut offiziell bestaetigt, ohne wesentliche Aenderung.
- `UPDATED`: bekannte Stelle mit wesentlicher Aenderung an Titel, Standort, Beschreibung, Anforderungen, Arbeitsmodell, Status oder offizieller URL.
- `CLOSED`: offiziell als geschlossen erkannt.
- `REMOVED`: nach erfolgreichem Scan der offiziellen Quelle nicht mehr auffindbar, ohne explizite Schliessungsseite.
- `INVALID`: Quelle oder Daten reichen nicht fuer einen belastbaren Treffer.

Ein Fehler beim Scan einer Quelle darf aktive Stellen nicht automatisch auf `CLOSED` oder `REMOVED` setzen. `last_seen` darf nur aktualisiert werden, wenn die Stelle offiziell wiedererkannt wurde.

## Daily Workflow

Ein Tageslauf muss deterministisch und wiederholbar sein:

1. Zustand laden und Schema-Version validieren.
2. Lauf-ID erzeugen und Lock pruefen.
3. Firmen nach Prioritaet auswaehlen.
4. Quellenadapter je Firma mit Timeout und Fehlerisolation ausfuehren.
5. Nur offizielle oder offiziell angebundene URLs akzeptieren.
6. Rohstellen normalisieren und kanonisieren.
7. Stellen klassifizieren und A/B/C priorisieren.
8. Deduplikation gegen vorhandene Historie ausfuehren.
9. Statusmaschine anwenden und ChangeEvents schreiben.
10. Bericht und maschinenlesbares Ergebnisartefakt erzeugen.
11. Lock freigeben und ScanRun finalisieren.

Ein Fehler bei einer einzelnen Firma darf den Gesamtlauf nicht abbrechen, sofern Persistenz und Abschlussbericht noch konsistent erzeugt werden koennen.

## Deduplikation

Die Identitaet einer Stelle wird in dieser Reihenfolge bestimmt:

1. Offizielle Job-ID der Unternehmens- oder ATS-Seite.
2. Firmengebundene ATS-ID.
3. Kanonische offizielle Detail-URL.
4. Zusammengesetzte Merkmale aus Unternehmen, Standort, Titel und stabilen Quellbestandteilen.

Trackingparameter, Session-IDs und reine Suchfilter duerfen keine neue Stelle erzeugen. Titel- oder Beschreibungsaenderungen erzeugen `UPDATED`, nicht automatisch `NEW`. Eine moegliche Neuausschreibung darf nur als neue Stelle behandelt werden, wenn die Identitaetsmerkmale dies belastbar begruenden; sonst ist der Fall als unsicher zu markieren.

## Ausgabeformat

Jeder Daily-Run erzeugt mindestens einen Markdown-Bericht und soll zusaetzlich ein JSON-Artefakt erzeugen.

Pflichtabschnitte:

- Neue passende Stellen.
- Aktive passende Stellen.
- Wesentliche Aenderungen.
- Geschlossene oder entfernte Stellen.
- Neue oder geaenderte Unternehmen.
- Fehler und unsichere Quellen.
- Statistik des Laufs.
- A/B/C-Priorisierung mit kurzer Begruendung.

Jeder verifizierte Treffer enthaelt mindestens Titel, Unternehmen, Standort, Arbeitsmodell, Prioritaet, Status, offizielle URL, `first_seen`, `last_seen`, Quelltyp und Bewertungsbegruendung. Unklare Werte werden als `UNKNOWN` ausgegeben.

## Qualitaetssicherung

### Muss

- Schema-, Modell- und Repository-Funktionen erhalten fokussierte Funktionstests.
- Quellenverifikation wird mit offiziellen URLs, ATS-URLs und abgelehnten Aggregator-URLs getestet.
- Deduplikation wird mit mindestens zwei Laeufen getestet, damit bekannte Stellen im zweiten Lauf nicht erneut `NEW` werden.
- Statuslogik wird fuer `NEW -> ACTIVE -> UPDATED -> CLOSED/REMOVED` getestet.
- Live-Webrecherche ist keine Voraussetzung fuer deterministische Funktionstests.

### Akzeptanzkriterien

- Keine Ausgabe eines Treffers ohne offizielle URL.
- Keine erfundenen Firmen, Stellen, URLs, Geodaten oder Gehaelter.
- Bekannte unveraenderte Stellen erscheinen ueber zwei Testlaeufe nicht erneut als `NEW`.
- Fehlgeschlagene Firmen-Scans schliessen bestehende Stellen nicht automatisch.
- Report und Persistenz bleiben nach Abbruch oder erneutem Lauf konsistent.
- `.\ci.cmd self-check` ist gruen, bevor fachliche Roadmap-Punkte als abgeschlossen gelten.

## Betrieb

- Der regulaere Einstieg erfolgt ueber `.\ci.cmd`.
- Fachliche Commands wie `daily-run`, `daily-run-status` und spaeter `supertest` muessen nicht-interaktiv laufen.
- Devserver und SonarQube werden nur ueber vorgesehene Hintergrund-Commands gestartet.
- Secrets duerfen nur aus erlaubten lokalen Quellen oder Umgebungsvariablen gelesen werden und nie in Logs, Reports, Todo-, Handoff- oder Git-Diffs erscheinen.

## Offene Annahmen

- `UNKNOWN`: Endgueltige Persistenztechnologie ist noch nicht festgelegt.
- `UNKNOWN`: Konkrete Firmen-Seedliste ist noch nicht erstellt.
- `UNKNOWN`: Exakte Geodistanzlogik fuer den 20-km-Umkreis ist noch nicht implementiert.
- `UNKNOWN`: Konkrete ATS-Systeme und Adapterprioritaeten werden erst nach Firmeninventar festgelegt.
- `UNKNOWN`: Automatischer Scheduler ist noch nicht eingerichtet.
