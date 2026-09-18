# JA-056 – Suchaufträge und Sichtungsstände

## Lokaler Vertrag

`jobagent:personal:v2.saved_searches` ist ein optionaler Bereich des bestehenden browserlokalen Zustands. Er enthält höchstens 50 Suchaufträge. Ein Auftrag besteht aus stabiler `search_id`, einem nach Trim 1–80 Unicode-Codepoints langen Namen, den kanonischen Stellenfiltern, Erstellungs-/Änderungszeit und einem Sichtungs-Baselineobjekt.

Der Name wird NFKC-normalisiert, ohne Akzentunterscheidung und mit vereinheitlichten Leerzeichen auf Duplikate geprüft. Filter speichern nur Freitext, Firma, Beruf, Gebiet, Arbeitsbedingungen, Alter, Favoriten-/Bewerbungsmodus, Sortierung und Sichtbarkeit. Kalenderdatum, Detail-ID, aktuelle Seite, Notizen und andere persönliche Bewerbungsdaten gehören nicht in den Suchauftrag.

## Sichtungs-Baseline

Eine Baseline ist ausschliesslich eine explizit gespeicherte, erfolgreiche Reportgeneration mit `generation_id`, bestätigten sichtbaren Job-IDs, fachlichen Change-Event-IDs und `confirmed_at`. Ein erstmalig gespeicherter Suchauftrag erhält die aktuell sichtbare Ergebnismenge als Baseline und zeigt daher keine neuen Treffer.

Reload, Navigation und Filtervorschau ändern die Baseline nicht. Nur die explizite Aktion „Als gesehen markieren“ ersetzt sie atomar durch die genau übergebene Generation und Ergebnismenge. Fehlende, ungültige oder nicht publizierte Vergleichswerte ergeben `comparison_unavailable`; der alte Stand bleibt unverändert.

## Vergleichsausgabe

Der Vergleich verwendet die bereits kanonisch gefilterte aktuelle Ergebnismenge; er implementiert keinen zweiten Filteralgorithmus. Er trennt:

- `new_job_ids`: sichtbare IDs ausserhalb der bestätigten Menge, Beschriftung „Neu in dieser Suche“;
- `changed_job_ids`: weiterhin sichtbare bestätigte IDs mit einer fachlichen, noch nicht bestätigten Change-Event-ID;
- `personal_visibility_job_ids`: erst durch eine lokale persönliche Auswahl sichtbare IDs, nicht als Stellenfund.

Ein neuer Renderer, ein Abrufzeitwechsel ohne fachliches Event und ein Fehler ohne Datenverlust erzeugen keinen neuen Treffer. Suchaufträge lösen keine Netzwerkaktion oder Erfassung aus.
