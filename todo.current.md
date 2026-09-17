# Todo (current)

Active: _(none)_

- [open] TD-0066 QA-007 Deterministischen Startvertrag des Vollsupertests wiederherstellen #comment: Der beauftragte Lauf `./ci.cmd supertest` brach beim ersten geplanten Fall `QA-006-CI-CONTRACT` ab. Der Runner meldete für `pwsh -NoProfile -File tests/Test-JobAgentCiContracts.ps1` Exit-Code 5, ohne Standardausgabe oder -fehler, und führte die verbleibenden 28 von 29 Fällen nicht aus. Die Ursache ist noch nicht gesichert; dieser Punkt begrenzt die Analyse auf reproduzierbare Vertrags- und Runnerpfade und verlangt einen vollständig nachweisbaren grünen Vollsupertest.
