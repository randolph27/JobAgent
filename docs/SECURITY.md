# Sicherheits- und Vertrauensmodell

## Geschützt

- zufällige oder unbeabsichtigte Drift der zentral manifestierten Dateien;
- fehlende, vergrößerte oder inhaltlich geänderte Runtime-Dateien im Projekt;
- unerwartete Dateien unter `.ci/bin` und unerwartete Skripte in `.ci/tools`;
- Reparse Points in zentralen Quellen, Projektzielpfaden und verwalteten Dateien;
- Windows Alternate Data Streams auf geprüften Release-/Runtime-Dateien;
- paralleles Run/Install/Update/Repair desselben kanonischen Projektpfads;
- lokale Selbst-Reparatur oder Repinning der Vertrauensbasis;
- Änderung der Runtime während eines Child-Laufs.

## Nicht geschützt

Der Bootstrap-Manager, das Manifest und die Profile liegen derzeit in derselben beschreibbaren ACL-Domäne. Ein lokaler Benutzer, der sowohl Code als auch Manifest ändern kann, kann passende neue Hashes erzeugen oder den Manager vor seiner Selbstprüfung verändern. Das Manifest ist deshalb Drift-Erkennung, keine kryptografische Authentizität.

Auch `ReadOnly` ist nur ein Schutz gegen versehentliche Änderungen. Es ersetzt keine ACL.

## Empfohlene Härtung vor Mehrbenutzerbetrieb

1. Bootstrap-Verzeichnis auf Administratoren und einen dedizierten Release-Account als Writer beschränken; Entwickler nur lesen/ausführen.
2. Release-Manifest außerhalb der Writer-Domäne signieren oder eine detached Signatur mit fest verankertem öffentlichen Schlüssel prüfen.
3. Publisher und Runtime in getrennten Prozessen/Identitäten ausführen.
4. PowerShell- und Profilskripte optional mit vertrauenswürdiger Code-Signing-Zertifikatskette signieren.
5. Backup-Retention und Zugriffsschutz definieren, da Backups alte Konfigurationen enthalten können.

ACLs wurden nicht automatisch verändert. Das wäre eine systemweite, potenziell aussperrende Aktion und benötigt eine explizite Freigabe.

## Geheimnisse

- Geheimnisse gehören nicht in Profile, Kataloge, Logs oder Backups.
- Ubuntu akzeptiert `OPENAI_API_KEY_FILE`; der historische Pfad bleibt nur als Kompatibilitätsfallback erhalten.
- Sonar-Tokens und Connection Strings sind über Umgebungsvariable oder projektlokale private, ignorierte Dateien bereitzustellen.
- Vor Freigabe eines Backups ist dessen Inhalt gesondert auf Geheimnisse zu prüfen.

