---
name: skill-template
description: Vorlage für einen spec-konformen Agent Skill. Ersetze diesen Text durch WAS der Skill tut UND WANN er genutzt werden soll (der Agent nutzt genau diese Beschreibung als Auto-Aktivierungs-Trigger). Beispiel: "Erzeugt einen Conventional-Commit-Message-Entwurf aus gestagten Änderungen. Nutze diesen Skill, wenn ein Commit vorbereitet werden soll."
# Optionale Standardfelder (bei Nichtgebrauch entfernen):
# paths: "src/**/*.ts, src/**/*.tsx"      # Skill nur bei passenden Dateien einblenden
# disable-model-invocation: true          # nur explizit via /skill-name, keine Auto-Aktivierung
# allowed-tools: "Read, Shell"            # Least Privilege — nie mehr als modules/tools.md erlaubt
# metadata: { owner: "team-x", version: "0.1.0" }
---

# <Skill-Titel>

> Kopiere diesen Ordner ins **Zielprojekt** nach `.cursor/skills/<name>/`
> (oder `.agents/skills/<name>/`) — **nicht** in den Vendor-Clone des Gesetzbuchs.
> `name` im Frontmatter MUSS dem Ordnernamen entsprechen. Governance: `modules/skills.md`
> (Kompatibilitäts-Stub: `skills-policy.md`).

## Wann dieser Skill greift

Kurz und präzise: die Aufgaben-Situationen, in denen der Agent diese Prozedur wählen soll.
(Konsistent mit `description` oben — diese steuert die Auto-Aktivierung via Progressive
Disclosure.)

## Voraussetzungen

- [ ] Werkzeug/Kontext 1 (z. B. „gestagte Änderungen vorhanden")
- [ ] Werkzeug/Kontext 2

## Schritte (Prozedur)

1. **Schritt 1** — konkrete, imperativ formulierte Aktion.
2. **Schritt 2** — inkl. exaktem Befehl, z. B. `git diff --staged`.
3. **Schritt 3** — Ergebnis/Übergabe.

## Definition of Done (ausführbar, `LAW-DOD`)

- [ ] Messbares Kriterium 1 — Nachweis: `<befehl>` → Exit `0`
- [ ] Kein Secret/PII in Ausgabe/Ressourcen (`gitleaks detect --source . --no-git` → Exit 0)

## Ressourcen (Progressive Disclosure — nur bei Bedarf laden)

- `references/<datei>.md` — Detailwissen, das NICHT ständig im Kontext liegen muss.
- `scripts/<datei>.sh` — optionales, lauffähiges Skript (Least Privilege).

## Grenzen / Nicht-Ziele

- Was dieser Skill bewusst NICHT tut (verhindert Scope-Creep und Fehl-Aktivierung).

<!--
Anti-Overengineering (modules/skills.md §3): Wenn dies eine Immer-an-Konvention ist,
gehört es in eine Rule / AGENTS.md — nicht in einen Skill. Ist es einmalig, gar nicht
persistieren. Prozedurale Writes (neuer/geänderter Skill) nur mit Versions-Bump +
Autorisierung (LAW-MEMORY, modules/memory.md).
-->
