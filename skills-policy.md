# Skills-Policy — Governance für Agent Skills (SKILL.md)

> **Version:** 1.3.0
> **Status:** Verbindlich (normativ) — konkretisiert **Gesetz 9** (prozedurales Gedächtnis) für den Konstrukt-Typ *Skill*
> **Bezug:** `AGENTS.md` §3.14 / §8 (prozedurale Writes), `memory-policy.md` §1 (CoALA `procedural`), §8 (Cursor-Integration), `tools-registry.md` §3.9 / §4 / §8, `workflow-cfg.md` (N1/N7)

Dieses Dokument schließt eine bewusste Lücke: Das Gesetzbuch **referenziert** „Skills"
mehrfach als **prozedurales Gedächtnis** (`memory-policy.md` §1, §7; `tools-registry.md`
§3.9, §8; `AGENTS.md` §3.14), definierte den Begriff bisher aber nicht. Diese Policy
legt **verbindlich** fest, **was** ein Skill ist, **wo** Skills leben, **wann** ein Skill
gegenüber Rule / `AGENTS.md` / MCP-Tool das richtige Konstrukt ist, und **wie** Skills als
prozedurales Gedächtnis regiert werden. Sie **liefert selbst keine projektspezifischen
Skills** — die Begründung steht in §7.

---

## 1. Was ist ein Skill? (SOTA-Grounding 2025–2026)

Ein **Agent Skill** ist ein Ordner mit einer `SKILL.md`-Datei (YAML-Frontmatter +
Markdown-Anweisungen) plus optionalen Skripten und Ressourcen, der einem Agenten
**eine konkrete, wiederholbare, mehrschrittige Prozedur** beibringt.

**Verbindliche Fakten (Stand 2026), auf die diese Policy sich stützt:**

- **Offener Standard.** Anthropic führte *Agent Skills* im Oktober 2025 ein und
  veröffentlichte die Spezifikation am 18. Dezember 2025 als **offenen Standard**
  (`agentskills.io`, verwaltet über die Agentic AI Foundation). Ein spec-konformer
  Skill läuft **plattformübergreifend** (Cursor, Claude Code, Codex CLI u. a.) ohne
  Änderung — das ist der zentrale Vorteil gegenüber IDE-spezifischen Rules.
- **Progressive Disclosure** (Kernprinzip, hält das Kontextfenster schlank — direkt
  im Dienst von **Gesetz 5**, Kontext-Budget/Handover):
  1. **Discovery** (~50–100 Tokens/Skill): Nur `name` + `description` werden beim
     Session-Start in den Kontext geladen.
  2. **Activation** (< ~5000 Tokens empfohlen): Der volle `SKILL.md`-Body wird erst
     geladen, wenn eine Aufgabe zur `description` passt.
  3. **Resources** (nach Bedarf): Gebündelte Dateien (Skripte, Referenzen, Assets)
     werden nur bei Bedarf nachgeladen.
- **Skill vs. MCP** (komplementär, nicht konkurrierend): **MCP** standardisiert, *wie*
  ein Agent sich mit Werkzeugen verbindet; ein **Skill** standardisiert, *wie* ein Agent
  eine Prozedur lernt. Beide sind getrennte Schichten (`tools-registry.md` §4).

**`SKILL.md`-Frontmatter (Standardfelder):**

| Feld | Pflicht | Bedeutung |
|------|---------|-----------|
| `name` | ✅ | Kleinbuchstaben/Ziffern/Bindestriche; **muss dem Ordnernamen entsprechen** |
| `description` | ✅ | *Was* der Skill tut **und wann** er genutzt wird (Trigger für Auto-Aktivierung) |
| `paths` | ❌ | Glob(s); Skill nur bei passenden Dateien einblenden (Scoping) |
| `disable-model-invocation` | ❌ | `true` → nur explizit via `/skill-name`, keine Auto-Aktivierung |
| `allowed-tools` | ❌ | Vorab freigegebene Werkzeuge (Least Privilege; Standard-Feld, experimentell — nicht Cursor-nativ, primär Claude Code) |
| `metadata` | ❌ | Freie Key-Value-Zusatzinfos |

---

## 2. Skill in der CoALA-Taxonomie (Anbindung an Gesetz 9)

Ein Skill ist **prozedurales Gedächtnis** (`memory-policy.md` §1: „*Wie* gehandelt wird:
die Gesetze selbst, Workflows, **Skills**, Tool-Register"). Damit gilt für Skills die
**höchste Schreib-Risiko-Stufe** der CoALA-Ordnung (`episodic < semantic < procedural`):

> **Ein vergifteter oder fehlerhafter Skill ist vergiftetes prozedurales Gedächtnis.**
> Er kann Bugs einführen oder einem Agenten erlauben, Designer-Absichten zu unterlaufen
> (CoALA §4.5, OWASP **ASI06**). Skills werden daher wie Gesetzestexte behandelt, nicht
> wie beiläufige Notizen.

Konsequenzen (verbindlich):

- **Skill-Writes = prozedurale Writes.** Erstellen/Ändern eines Skills unterliegt
  `AGENTS.md` §8 und `memory-policy.md` §1/§11(6): **niemals eigenmächtig** durch einen
  Sub-Agenten, sondern nur mit **Versions-Bump + Autorisierung** (Nutzer oder ausdrücklich
  autorisierter Orchestrator). „Silent Procedural Write" ist ein Verstoß.
- **Provenienz & Trust (Gesetz 9.4).** Ein aus untrusted Quelle bezogener Skill
  (Marketplace, fremdes Repo) ist `untrusted`/`unverified` und wird **quarantiniert und
  reviewt**, bevor er aktiviert wird — nicht blind ausgeführt.
- **Least Privilege (Gesetz 7 / `tools-registry.md`).** `allowed-tools` so eng wie möglich;
  ein Skill erweitert **nicht** die Werkzeugrechte einer Rolle über `tools-registry.md`
  hinaus.
- **Keine Secrets/PII (Gesetz 9.5).** Weder in `SKILL.md` noch in gebündelten Ressourcen.

---

## 3. Entscheidungsmatrix — Skill vs. Rule vs. `AGENTS.md` vs. MCP-Tool

> **Kernheuristik:** *Immer-an-Kontext* → Rule/`AGENTS.md`. *Auf-Abruf-Prozedur* → Skill.
> *Werkzeug-Anbindung* → MCP. *Einmalig/trivial* → gar nichts persistieren.

| Konstrukt | Aktivierung | Länge/Form | Typischer Inhalt | CoALA-Layer / Scope |
|-----------|-------------|------------|------------------|---------------------|
| **`AGENTS.md`** (Root/nested) | Immer gelesen | kurz–mittel | Projektfakten, Konventionen, Build/Test-Kommandos | `semantic`/`procedural`, `project` |
| **`.cursor/rules/*.mdc`** | `alwaysApply` / `globs` / agent-requested | kurz (Zeilen–Hunderte) | Harte Constraints, Stil, Pfad-gescopte Verbote | `procedural`/`semantic`, `project` |
| **Skill (`SKILL.md`)** | **On-Demand** (Auto per `description` oder `/name`) | länger, Schritt-für-Schritt | **Wiederholbare, mehrschrittige Prozeduren** (Release-Checkliste, Migration, strukturiertes Review) | `procedural`, `project`/`user`/`global` |
| **MCP-Tool** | Werkzeugaufruf zur Laufzeit | Server + Schema | Anbindung externer Fähigkeiten/Daten | Werkzeugschicht (nicht Gedächtnis) |

**Wähle einen Skill, wenn ALLE gelten:**
1. Die Anweisung ist eine **Prozedur** (mehrere Schritte, definierte Reihenfolge/DoD),
   nicht nur eine kurze Regel.
2. Sie wird **nur bei bestimmten Aufgaben** gebraucht (nicht bei jedem Prompt) — sonst
   gehört sie in eine Rule / `AGENTS.md` (Immer-an).
3. Sie ist **wiederverwendbar** und profitiert von **Progressive Disclosure**
   (zu lang, um sie ständig im Kontext zu halten).
4. Portabilität über Agenten hinweg ist erwünscht (Cursor + Claude Code + Codex …).

**Wähle KEINEN Skill (Anti-Overengineering), wenn:**
- Es eine **Immer-an-Konvention** ist („nutze TypeScript", „keine generierten Dateien
  editieren") → **Rule** / `AGENTS.md`.
- Es **einmalig** ist → gar nicht persistieren (Kontext genügt; vgl. `memory-policy.md`
  §6, Gesetz 9.6 Selektive Persistenz).
- Es reine **Werkzeug-Anbindung** ist → **MCP**, kein Skill.
- Es die **Kern-Gesetze dupliziert** (Bootstrap, Orchestrator-Delegation, Triage, DoD-Gates
  sind **immer-an** und in `AGENTS.md`/`workflow-cfg.md` normiert — sie sind per Definition
  **keine** On-Demand-Skills; siehe §7).

---

## 4. Wo leben Skills? (Ort & Scope — kein Leakage)

Skills leben im **Zielprojekt** bzw. im Nutzerprofil, **nicht** im Vendor-Clone dieses
Gesetzbuchs (vgl. Drei-Ebenen-Trennung, `AGENTS.md` §0.1 / `README.md`).

| Ort | Scope (Gesetz 9.1) | Wirkung |
|-----|--------------------|---------|
| `.cursor/skills/<name>/SKILL.md` · `.agents/skills/<name>/SKILL.md` | `project` | Mit dem Repo geteilt (Team) |
| `apps/web/.cursor/skills/<name>/SKILL.md` (nested, Monorepo) | `project` (pfad-gescopt) | Nur bei Dateien unter dem Teilbaum |
| `~/.cursor/skills/…` · `~/.agents/skills/…` | `user` | Über Projekte hinweg (**Leakage-Gefahr**, s. u.) |
| `.claude/skills/…` · `.codex/skills/…` (+ `~`-Varianten) | project/user | Cross-Agent-Kompatibilität (werden ebenfalls geladen) |

> **Gesetz 9.2 (Kein Cross-Project-Leakage) gilt für Skills.** Projektspezifische Skills
> (Build-/Deploy-Schritte, Framework-Constraints eines Repos) gehören in `project`-Scope,
> **niemals** ungeprüft nach `~/.cursor/skills` (`user`/`global`). `user`-Skills sind
> ausschließlich für **genuin projektübergreifende** Prozeduren.

**Naming/Struktur:** `name` == Ordnername (Kleinbuchstaben/Bindestriche). Kategorien via
Unterordner erlaubt (`.cursor/skills/shipping/deploy-staging/SKILL.md`); der Name kommt
vom `SKILL.md`-Elternordner, nicht von der Kategorie. Detail-Dateien (References/Assets)
werden **nicht** automatisch geladen — nur via Progressive Disclosure referenziert.

---

## 5. DoD & ausführbare Nachweise für Skills (Gesetz 6-konform)

Wie alles in diesem Regelwerk gilt: **ausführbare Nachweise statt Prosa.** Ein Skill ist
erst „fertig", wenn:

| Gate | Nachweis | Erfolg |
|------|----------|--------|
| Frontmatter valide | `name` == Ordnername, `description` vorhanden (was **und wann**) | erfüllt |
| Body-Budget | `SKILL.md`-Body im empfohlenen Rahmen (< ~500 Zeilen / < ~5000 Tokens); Rest in Ressourcen | erfüllt |
| Kein Secret/PII | `gitleaks detect --source <skill-dir> --no-git` | Exit 0 |
| Referenzierte Skripte lauffähig | jeweiliges Test-/Lint-Kommando (`tools-registry.md` §3) | Exit 0 |
| Injection-/Poisoning-Screening (untrusted Herkunft) | Review + `memory.poisoning_checks.injection_scan` | `passed` / dokumentierte Quarantäne |

Ergebnisse landen unter `proof-artifacts/`; prozedurale Skill-Writes werden mit
Versions-Bump im betreffenden Skill dokumentiert (analog `AGENTS.md` §8).

---

## 6. Skill-Lebenszyklus im CFG (Anbindung N1/N7)

Skills sind prozedurales Gedächtnis und damit an denselben Gates verankert wie übriges
Gedächtnis (`workflow-cfg.md`, `memory-policy.md` §9):

- **N1 (Ingestion):** Verfügbare Skills werden entdeckt (Discovery: `name`+`description`).
  Herkunft/Trust prüfen (Gesetz 9.4); untrusted → `quarantine`, nicht auto-aktivieren.
  Aktivierung nur bei Aufgaben-Match.
- **N7 (Consolidation):** Ergab die Aufgabe eine **durable, wiederverwendbare Prozedur**,
  ist sie **Kandidat** für einen neuen/aktualisierten Skill (`memory.pending_writes[]`,
  `layer: procedural`). Persistiert wird **nur** mit Versions-Bump + Autorisierung
  (§2, `AGENTS.md` §8) und nach Secret/PII- + Injection-Screening.

> **Terminierung bleibt gewahrt.** Skill-Discovery/-Aktivierung sind endliche, begrenzte
> Operationen; sie erzeugen keine neuen CFG-Zyklen und erhöhen weder `cycle` noch `depth`
> (vgl. `workflow-cfg.md` §6.5, `proofs/termination-proof.md` §7.1).

---

## 7. Warum dieses Gesetzbuch KEINE Skills ausliefert

Bewusste, begründete Entscheidung (nicht Auslassung):

1. **Anti-Cross-Project-Leakage (Gesetz 9.2).** Die meisten wertvollen Skills sind
   **projekt- oder aufgabenspezifisch** (Deploy-Pipeline, DB-Migration, Framework-Review).
   Sie in ein **universelles** Gesetzbuch zu legen und projektweit auszurollen, verletzt
   exakt die Leakage-Regel, die dieses Regelwerk selbst aufstellt.
2. **Anti-Overengineering (Gesetz 2).** Die Kern-Prozeduren dieses Systems — Bootstrap,
   Orchestrator-Delegation, Triage, Handover, DoD-Gates — sind **immer-an** und bereits in
   `AGENTS.md` / `workflow-cfg.md` / `handover-template.md` normiert. Als On-Demand-Skills
   verpackt wären sie (a) **falsch klassifiziert** (Skills sind per SOTA-Definition *nur bei
   Bedarf*, nicht bei jedem Prompt) und (b) eine **Duplikation** der Gesetze — die
   gefährlichste Form prozeduraler Redundanz.
3. **Trennung Gesetz ↔ Ausführung.** Das Gesetzbuch definiert die **Regeln** (Verfassung);
   Skills sind **projektspezifische Ausführungsprozeduren**. Ebenen mischen widerspräche der
   Drei-Ebenen-Trennung (`AGENTS.md` §0.1).

**Was das Gesetzbuch stattdessen liefert:** diese **Policy** (das Gesetz *über* Skills)
und **ein spec-konformes Template** (`templates/skill-template/SKILL.md`) zum Kopieren ins
Zielprojekt — analog zu `handover-template.md`. So wird der offene Standard **konkret und
paste-ready**, ohne fremde Projekte zu verunreinigen.

---

## 8. Quellen & Grundlagen

- **Anthropic Agent Skills** (Okt 2025) → offener Standard (18. Dez 2025), `agentskills.io`,
  Agentic AI Foundation; `SKILL.md`-Format, Frontmatter, **Progressive Disclosure** (3 Stufen).
- **Cursor Docs — Skills:** Orte `.cursor/skills/`, `.agents/skills/`, `~/.cursor/skills/`,
  `~/.agents/skills/`; Kompatibilität `.claude/skills`, `.codex/skills`; nested Scoping;
  Frontmatter `name`/`description`/`paths`/`disable-model-invocation`; `/migrate-to-skills`.
  Cursor empfiehlt Skills als bevorzugten Weg für On-Demand-Prozeduren; Rules bleiben für
  Immer-an/Path-gescopte Enforcement.
- **Skill vs. Rule** (2026-Praxis): Rules = Immer-an-Kontext/Constraints; Skills = On-Demand-
  Workflows, cross-agent portabel.
- **MCP** (Linux Foundation, Dez 2025) als komplementäre Werkzeug-Schicht — nicht Skill-Ersatz.
- CoALA (arXiv:2309.02427) — Skills als `procedural` Memory, höchste Schreib-Risiko-Stufe.
- OWASP **ASI06** (Memory & Context Poisoning) — vergifteter Skill = vergiftetes Prozedural-Memory.
- Anbindung im Regelwerk: `memory-policy.md` §1/§8/§11, `AGENTS.md` §3.14/§8,
  `tools-registry.md` §3.9/§4/§8, `workflow-cfg.md` §6.5.
