# agent-rules — Das Gesetzbuch für Agenten-gesteuerte Software-Projekte

> **Version:** 1.3.0  
> **Status:** Verbindlich (normativ)  
> **Sprache:** Deutsch (Nutzerdokumentation); technische Identifikatoren und JSON-Schlüssel auf Englisch

Dieses Repository ist die **absolute Verfassung** für alle zukünftigen, agenten-gesteuerten Software-Projekte. Es definiert Hierarchie, Kontrollfluss, Rollen, Zustandsverfolgung, Kontext-Übergabe und Definition of Done mit **ausführbaren Nachweisen** — nicht mit Absichtserklärungen.

Jeder Agent, der eine Nutzeranfrage bearbeitet, **muss** dieses Repository zuerst lesen (Bootstrap, CFG-Knoten 1), bevor Code, Pläne oder Artefakte erzeugt werden.

---

## Die Gesetze (Kurzform)

| # | Gesetz | Kerndokument |
|---|--------|--------------|
| 1 | **Hierarchie & Tiefenlimit** — Empfangender Agent = Orchestrator; delegiert nur; max. Baumtiefe 4 | `AGENTS.md` §1–2 |
| 2 | **CFG & Triage** — Input → Bootstrap → Triage (Fast/Standard/Deep); max. 3 Zyklusversuche | `workflow-cfg.md` |
| 3 | **Dynamisches Rollenmodell** — Elite-Rollen mit klarem Mandat und DoD | `AGENTS.md` §3 |
| 4 | **Zustandsverfolgung** — Orchestrator kennt globalen Zustand via `.agent-state.json` | `schemas/agent-state.schema.json` |
| 5 | **Kontext-Handover** — Kein Agent erreicht Kontextlimit; Rotation bei ≥ 80 % | `handover-template.md` |
| 6 | **DoD & ausführbare Beweise** — Knotenwechsel nur mit harten Metriken (Tests, TLA+ CLI) | `workflow-cfg.md`, `tools-registry.md` |
| **9** | **Memory / Gedächtnis** — persistentes Gedächtnis (CoALA: working/episodic/semantic/procedural) getrennt vom Kontext; kuratiert, gescoped, provenienzgesichert, TTL; ASI06-Poisoning-Abwehr | **`memory-policy.md`**, `AGENTS.md` §5a |

> Ergänzend verbindlich: **Gesetz 7** (Kontext-Isolation / Least Context) und
> **Gesetz 8** (ein Orchestrator pro Anfrage-Baum). Gesetz 9 (Memory) wird an den
> CFG-Gates **N1** (Ingestion) und **N7** (Consolidation) durch den **Memory Curator**
> durchgesetzt.

---

## Repository-Struktur

```
agent-rules/
├── README.md                    # Diese Übersicht
├── AGENTS.md                    # Rollen- und Regelwerk (Verfassung)
├── workflow-cfg.md              # Control-Flow-Graph + Terminierungsbeweis
├── memory-policy.md             # Gedächtnis-Governance (Gesetz 9): CoALA, Scoping, TTL, ASI06
├── skills-policy.md             # Skill-Governance: SKILL.md, Skill-vs-Rule-vs-MCP, Scoping
├── tools-registry.md            # Erlaubte Werkzeuge und CLI-Befehle je Rolle
├── handover-template.md         # Normiertes Handover-Protokoll (inkl. Memory-Übergabe §7a)
├── CHANGELOG.md                 # Versionierte Änderungshistorie des Gesetzbuchs
├── .agent-state.json            # Beispiel-Instanz (siehe Schema)
├── .gitignore
├── schemas/
│   └── agent-state.schema.json  # JSON Schema für Maschinenlesbarkeit
├── proofs/
│   └── termination-proof.md     # Formale Ergänzung zum CFG-Beweis
├── scripts/
│   └── verify-proofs.sh         # Ausführbare DoD-Beweise (ajv, gitleaks, TLC)
├── specs/
│   ├── workflow.tla             # TLA+-Spezifikation (Referenz für Deep-Track)
│   └── workflow.cfg             # TLC Model-Checker-Konfiguration (kanonisch)
├── workflows/
│   └── triage-decision-matrix.md  # Entscheidungsmatrix für Triage (N2)
├── prompts/                       # Verbraucher-Vorlagen (Nicht-Gesetzbuch)
│   ├── README.md                    # Hinweis: keine normativen Regeln
│   └── project-bootstrap-prompt.md  # Copy-paste Prompt fürs Zielprojekt
└── templates/
    ├── handover-example.md          # Beispiel-Handover
    ├── handover-filled-example.md   # Ausgefülltes Referenz-Handover
    └── skill-template/
        └── SKILL.md                 # Paste-ready Skill-Vorlage fürs Zielprojekt
```

---

## Schnellstart für Orchestratoren

1. **Bootstrap (CFG N1):** Lese `AGENTS.md` → `workflow-cfg.md` → `tools-registry.md` → `handover-template.md` → `memory-policy.md`; führe **Memory Ingestion** durch (persistentes Projekt-Gedächtnis laden, Provenienz/TTL/Poisoning prüfen).
2. **State initialisieren:** Erzeuge oder lade `.agent-state.json` (inkl. `memory`-Objekt) gemäß `schemas/agent-state.schema.json`.
3. **Triage (CFG N2):** Wähle Fast-Track, Standard-Track oder Deep-Track.
4. **Delegieren:** Spawne Sub-Agenten mit Rollen-Mandat + Handover; aktualisiere `running_sub_agents` und `tree_depth`.
5. **DoD-Gates:** Knotenwechsel nur wenn alle Kriterien in `workflow-cfg.md` erfüllt und **nachweisbar** (Test-Exit-Code 0, TLA+ `tlc` OK, etc.).
6. **Memory Consolidation (CFG N7):** Schreibe durable Learnings (Sackgassen, verifizierte Fakten) mit Provenienz/TTL; expiriere Stale; Secret/PII- + Injection-Scan; Snapshot.
7. **Abschluss:** Setze `phase: "done"` oder `phase: "blocked"`; liefere Nutzerantwort.

---

## Konsum im Zielprojekt

Dieses Repository ist das **standalone Gesetzbuch** — kein Teil des Produktcodes. Zielprojekte beziehen es per Clone/Pull in einen **gitignorierten Vendor-Pfad** und halten Laufzeit-Artefakte getrennt davon.

### Empfohlenes Muster

1. **Hosten:** `agent-rules` auf GitHub als eigenes Repository versionieren und pflegen.
2. **Beziehen:** Im Zielprojekt klonen oder aktualisieren (Pfad frei wählbar):
   ```bash
   git clone https://github.com/src-dbgr/agent-rules.git .agent-rules
   # Alternativen: vendor/agent-rules/, tools/agent-rules/ — nicht vorgeschrieben
   ```
3. **Bootstrap (CFG N1):** Orchestrator liest vom Vendor-Pfad:
   `AGENTS.md` → `workflow-cfg.md` → `tools-registry.md` → `handover-template.md` → `memory-policy.md`
4. **Runtime:** Projekt-spezifischer Zustand in `runtime/` (gitignored), z. B. `.agent-state.json` und `handover-*.md` — **nicht** im Vendor-Clone.

### Drei Ebenen (nicht vermischen)

| Ebene | Ort | Zweck |
|-------|-----|-------|
| **Gesetzbuch** | GitHub `agent-rules` / Vendor-Clone | Normative Regeln, CFG, Rollen, Tools |
| **Laufzeit** | `runtime/` im Zielprojekt (gitignored) | State, Handovers, Memory-Snapshots |
| **Projektkontext** | `AGENTS.md` / `.cursor/rules/` im Zielprojekt | Projekt-Konventionen — ergänzen das Gesetzbuch, ersetzen es nicht |

### Beispiel `.gitignore` (Zielprojekt)

```gitignore
# Agent-Gesetzbuch (Vendor, regelmäßig pullen)
.agent-rules/
# vendor/agent-rules/   # alternative, frei wählbar

# Agent-Laufzeit (projektspezifisch, nicht committen)
runtime/
```

### Beispiel Agent-Anweisung (paste-ready)

```
Bootstrap (CFG N1): Lies das Gesetzbuch aus dem Vendor-Pfad (z. B. .agent-rules/):
AGENTS.md → workflow-cfg.md → tools-registry.md → handover-template.md → memory-policy.md.
Runtime-State liegt in runtime/.agent-state.json — getrennt vom Vendor-Clone.
Die AGENTS.md des Zielprojekts ergänzt das Gesetzbuch, ersetzt es nicht.
```

Kein Backend, kein Submodule-Zwang — nur Clone/Pull und klarer Pfad im Bootstrap.

---

## Nicht-Gesetzbuch — Verbraucher-Vorlagen

Copy-paste-fertige Prompts für Zielprojekte — **nicht normativ**, nur Einstiegshilfe:

| Vorlage | Pfad |
|---------|------|
| Projekt-Bootstrap + Feature-Request | [`prompts/project-bootstrap-prompt.md`](prompts/project-bootstrap-prompt.md) |

**Nutzung:** Vorlage öffnen, GitHub-URL anpassen, Feature-Request unter `<!-- DEIN FEATURE-REQUEST HIER -->` einfügen, gesamten Inhalt in den Agent-Chat pasten. Der Agent lädt das Gesetzbuch, führt CFG N1 aus, arbeitet dann deine Anfrage ab. Details: [`prompts/README.md`](prompts/README.md).

---

## Skills — warum das Gesetzbuch die *Policy* liefert, nicht die Skills

Ein häufiges Missverständnis: „Das Bibel-Repo braucht ein `skills/`-Verzeichnis."
Es braucht die **Policy über Skills** — und die steht in **`skills-policy.md`**.

- **Was ein Skill ist:** ein Ordner mit `SKILL.md` (offener Agent-Skills-Standard,
  Progressive Disclosure), der eine **auf-Abruf** genutzte, mehrschrittige Prozedur lehrt —
  cross-agent portabel (Cursor, Claude Code, Codex …). In der CoALA-Taxonomie ist ein Skill
  **prozedurales Gedächtnis** (Gesetz 9) — höchste Schreib-Risiko-Stufe.
- **Skill vs. Rule vs. `AGENTS.md` vs. MCP:** Immer-an-Kontext → Rule/`AGENTS.md`;
  auf-Abruf-Prozedur → Skill; Werkzeug-Anbindung → MCP; einmalig/trivial → gar nichts
  persistieren. Vollständige Matrix: `skills-policy.md` §3.
- **Warum keine Skills im Gesetzbuch:** Skills sind überwiegend **projekt-/aufgaben-
  spezifisch**. Sie in ein universelles Gesetzbuch zu legen, verletzt **Gesetz 9.2**
  (kein Cross-Project-Leakage) und dupliziert die ohnehin *immer-an* geltenden Kern-Gesetze
  (Bootstrap, Delegation, Triage). Deshalb: **Policy + paste-ready Template**
  (`templates/skill-template/SKILL.md`), Skills selbst leben im **Zielprojekt**
  (`.cursor/skills/…`), nicht im Vendor-Clone. Begründung: `skills-policy.md` §7.

---

## Empirische Grundlagen

Die Architektur folgt etablierten Mustern aus der Multi-Agent-Literatur und Produktionspraxis (2025–2026):

- **Supervisor/Worker-Topologie** als Produktions-Default (LangGraph, Claude Agent SDK, OpenAI Agents SDK).
- **Deterministische Kontrollfluss-Graphen** statt offener Konversations-Schleifen (verhindert unkontrollierte Rekursion).
- **Strukturierte Handover-Briefs** statt vollständiger Chat-Historie (Kontext-Bloat-Vermeidung).
- **Test-Driven Agentic Development (TDAD)** — Verhalten als ausführbare Tests spezifizieren, nicht als Prosa.
- **Verhaltensbasierte Agent-Tests** (agentverify, Invarium, AgentProbe) — Tool-Sequenzen, Budgets, Sicherheitsinvarianten.
- **Bounded execution** — `max_depth`, `max_cycles`, Token-Budgets als Runtime-Guardrails, nicht Post-hoc-Alerts.
- **Hierarchisches Gedächtnis (CoALA)** — working/episodic/semantic/procedural als getrennte, gescopte Schichten; Memory-Stores (LangGraph `store`, Mem0, Zep/Graphiti, Letta) statt „alles im Kontext".
- **Memory als Angriffsfläche (OWASP ASI06)** — persistentes Gedächtnis wird provenienzgeprüft, TTL-behaftet und poisoning-gescreent (Agent Memory Guard-Muster).

Quellen: arXiv TDAD (2026), LangGraph State-Machine-Muster, OWASP LLM Top 10, OWASP Top 10 for Agentic Applications (ASI06), CoALA (arXiv:2309.02427), Mem0 (arXiv:2504.19413), Zep/Graphiti (arXiv:2501.13956), NIST SP 800-218 SSDF, FIPA/Contract-Net-Delegationsmuster.

---

## Lizenz & Änderungen

Änderungen an diesem Gesetzbuch erfordern bewusste Versionserhöhung in `AGENTS.md` und abgestimmte Aktualisierung aller referenzierten Dokumente. Jede Revision wird in `CHANGELOG.md` protokolliert (Auditierbarkeit). Sub-Agenten dürfen diese Gesetze **nicht** eigenmächtig abschwächen.
