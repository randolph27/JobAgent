# Handoff: JA-043 abgeschlossen, Fortsetzung mit JA-044

Stand: 2026-09-17. Arbeitszweig: `master`.

## Abgeschlossen

JA-043 ist nach `Roadmap_archive.md` rotiert. Der Datenvertrag ist in `docs/contracts/JA-043-jobboard-data.md` festgeschrieben und der Akzeptanznachweis in `docs/reviews/JA-043-acceptance.md`.

- `schemas/jobagent.schema.json`: optionales, strikt als ISO-8601 geprüftes `jobs[].published_at`.
- `src/JobAgent.StatusMachine.psm1`: normalisiert belegte Publikationszeiten nach UTC; fehlende Folgedaten entfernen keinen vorhandenen Wert.
- `src/JobAgent.Report.psm1`: projektiert die Quellenauskunft einer Stelle gegen eine feste Reportreferenz als `CURRENT`, `CHECK_PENDING` oder `FRESHNESS_UNKNOWN`; liefert getrennte Zähler für offene, aktuelle, überfällige, unbekannte und ausgeschlossene Stellen; Suchkarten zeigen Alter und Quellenstand.
- Tests: Schema, Persistenz, Statusmaschine und Report jeweils Exit 0. Die Reportfixture prüft die 7-Tage-Grenze exakt, plus eine Sekunde und eine fehlende Quellenbestätigung. Die Statusfixture prüft Normalisierung und Beibehaltung von `published_at` sowie den unveränderten `last_seen` bei Fehler/PARTIAL.

Kein Liveabruf, keine Umetikettierung von Produktionsdaten, keine neue Job-ID-Strategie und keine privaten Markierungen wurden eingeführt. Der Vollsupertest ist nach Nutzerregel als erledigt bewertet, weil er nicht als Abschlussanforderung beauftragt war.

## Neuer Anker: JA-044

Ziel: Den bereits vorhandenen Discovery-/Verifikations-/Scanpfad mit dem JA-043-Stellenvertrag verbinden. Firmen müssen trotz leerer, teilweiser oder fehlerhafter Quellen erhalten bleiben; nur ein vollständiger erfolgreicher Scan darf fehlende Jobs der betroffenen Quelle als `REMOVED` behandeln.

Reihenfolge:

1. Bestehende Fixtures und Tests in `Test-JobAgentCompanyInventory.ps1`, `Test-JobAgentSourceVerification.ps1`, `Test-JobAgentSourceAdapters.ps1`, `Test-JobAgentDailyRun.ps1` und `Test-JobAgentCoverage.ps1` prüfen.
2. Eine isolierte Mehrquellenfixture festlegen: bekannte Firma, eine neue verifizierbare Firma, Doppelhinweis, vollständiger leerer Scan und Fehlerquelle. Vorher die erwarteten Firmen-, Job- und Fehler-IDs definieren.
3. Nur nachgewiesene Übergabelücken in `CompanyInventory`, `SourceVerification`, `SourceAdapters`, `LiveScan`, `DailyRun` oder `Coverage` schließen. Keine Budget-/Concurrency-/Retry-Erhöhung, keine Login- oder CAPTCHA-Umgehung.
4. Ersten und identischen zweiten Fixturelauf ausführen: Retention, ID-Mengen, Quellenvollständigkeit, Fehler ohne falsche Schließung und fehlende Dubletten prüfen.
5. Akzeptanznachweis unter `docs/reviews/JA-044-acceptance.md` und Replaydaten unter `logs/jobagent/JA-044/acquisition-replay.json` erzeugen. Erst dann JA-044 rotieren und Todo/Handoff synchronisieren.

## Bekannte Grenzen

- Die globale Routeprüfung bleibt wegen elf vorbestehender Befunde in ignorierten lokalen Sonar-Lizenzdateien rot; diese Dateien nicht verändern.
- Ein vorhandener Sicherungs-Stash und historische Screenshotreferenzen bleiben unverändert.
- Die lokale Sonar-Laufzeit ist kein Nachweis nativer PowerShell-Analyse oder eines Quality Gates.
