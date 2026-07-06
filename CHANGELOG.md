# Changelog — agent-rules (Gesetzbuch)

Alle nennenswerten Änderungen an diesem Gesetzbuch werden hier dokumentiert.
Das Regelwerk verlangt für jede Änderung eine **bewusste Versionserhöhung**
(`AGENTS.md` §8, `README.md`); dieses Changelog macht diese Historie nachvollziehbar
(Auditierbarkeit, vgl. `AGENTS.md` §3.12 Compliance/Governance).

Format angelehnt an [Keep a Changelog](https://keepachangelog.com/);
Versionierung semantisch (MAJOR.MINOR.PATCH) auf das Gesetzbuch als Ganzes.

## [1.3.0] — 2026-07-06

### Added
- **Architektur-Konformitäts-Gate (Drift-Prävention ohne Bloat):** Schließt die
  Lücke, dass **Architektur-Drift** auf normalen Features (Standard-Track) bisher
  unadressiert war, weil der Architect ausschließlich Deep-Track-exklusiv ist.
  Neues, leichtgewichtiges **Architektur-Konformitäts-Gate** als Pflicht-DoD des
  **Tester & Reviewer** (N5) im **Standard- und Deep-Track**: wächterhafte
  Drift-Erkennung (Modulgrenzen, Abhängigkeitsrichtung, Schichtung, Muster) —
  **keine** Architektur-Autorschaft.
- **Begrenzter Eskalations-Rückkanal N5 → N3c (max 1×):** Stellt das Gate
  **echten** Architekturbedarf fest (neue Komponente/Abhängigkeitsrichtung/
  Querschnittsbelang), wird auf Deep-Track hochgestuft und der Architect
  nachträglich gespawnt — statt Drift still durchzuwinken. Symmetrisch zum
  bestehenden N5 → N3b (Anforderungslücke, max 1×).

### Changed
- **Prinzip „Architektur-Autorschaft vs. Architektur-Konformität"** eingeführt:
  Autorschaft (Entwurf/ADR/TLA+) bleibt Deep-Track-exklusiv (Anti-Overengineering);
  Konformität (Drift-Check) gilt auf Standard + Deep. Verankert in `AGENTS.md`
  (§2.5, §3.3, §3.5, §6-DoD-Tabelle N8), `workflow-cfg.md` (§1 ASCII, §2 N5-DoD,
  §3.1–3.3 Track-Pfade, §4, §5.1 Rückkanal-Tabelle, §6.3 Terminierung) und
  `workflows/triage-decision-matrix.md` (Rollen-Ketten, Anti-Overengineering-Regel 4).
- Versions-Bump aller Kerndokumente auf **1.3.0** (`AGENTS.md`, `README.md`,
  `workflow-cfg.md`, `memory-policy.md`, `skills-policy.md`, `tools-registry.md`,
  `handover-template.md`, `workflows/triage-decision-matrix.md`,
  `proofs/termination-proof.md`).
- `schemas/agent-state.schema.json` (`schema_version` const) und alle Instanzen/Beispiele
  (`.agent-state.json`, `handover-template.md`, `templates/handover-filled-example.md`) auf
  `1.3.0` gehoben. **Keine strukturelle Schemaänderung** — nur Versionskennung.

### Unchanged (bewusst)
- **`specs/workflow.tla` / `specs/workflow.cfg` nicht geändert:** Der neue
  Rückkanal N5 → N3c ist **one-shot** (max 1×) und wird — wie das bereits
  bestehende N5 → N3b — im formalen Modell als knoten-lokale, endliche Aktion
  abstrahiert. Die geprüften Invarianten (`InvCycle` `cycle ≤ 3`, `InvDepth`
  `depth ≤ 4`, `InvTerminal`) und der Terminierungs-/Deadlock-Beweis bleiben
  unverändert gültig (Begründung: `workflow-cfg.md` §6.3, `proofs/termination-proof.md` §7).
  Die CFG-Topologie ändert sich damit **nicht materiell**.

## [1.2.0] — 2026-07-06

### Added
- **`skills-policy.md`** — verbindliche Governance für **Agent Skills** (`SKILL.md`):
  schließt die Lücke, dass „Skills" als prozedurales Gedächtnis bisher referenziert,
  aber nicht definiert war. Enthält SOTA-Grounding (offener Agent-Skills-Standard,
  Progressive Disclosure), CoALA-Einordnung (Gesetz 9), Entscheidungsmatrix
  (Skill vs. Rule vs. `AGENTS.md` vs. MCP), Orte/Scoping (kein Cross-Project-Leakage),
  DoD/ausführbare Nachweise und die begründete Entscheidung, **keine** projektspezifischen
  Skills im Gesetzbuch auszuliefern.
- **`templates/skill-template/SKILL.md`** — spec-konforme, paste-ready Vorlage zum Kopieren
  ins Zielprojekt (`.cursor/skills/<name>/`), analog zu `handover-template.md`.
- **`CHANGELOG.md`** — diese Datei (schließt die Governance-Lücke „versionierte Revisionen
  gefordert, aber keine Änderungshistorie geführt").

### Changed
- Versions-Bump aller Kerndokumente auf **1.2.0** (`AGENTS.md`, `README.md`,
  `workflow-cfg.md`, `memory-policy.md`, `tools-registry.md`, `handover-template.md`,
  `workflows/triage-decision-matrix.md`, `proofs/termination-proof.md`).
- Querverweise auf `skills-policy.md` ergänzt in `AGENTS.md` (§3.14, §9 Quellen),
  `README.md` (Struktur + Skills-Abschnitt), `memory-policy.md` (§1, §7, §8-Cursor-Tabelle)
  und `tools-registry.md` (§3.9).
- `schemas/agent-state.schema.json` (`schema_version` const) und alle Instanzen/Beispiele
  (`.agent-state.json`, `handover-template.md`, `templates/handover-filled-example.md`) auf
  `1.2.0` gehoben. **Keine strukturelle Schemaänderung** — nur Versionskennung.

## [1.1.0] — 2026-07-06

### Added
- **`memory-policy.md`** — **Gesetz 9** (Memory/Gedächtnis) als erstklassiges Gesetz:
  CoALA-Taxonomie (working/episodic/semantic/procedural), Scoping, TTL/Bi-Temporalität,
  Provenienz, ASI06-Poisoning-Abwehr, Cursor-Integration.
- `memory`-Objekt im State-Schema; Memory-Gates an N1 (Ingestion) und N7 (Consolidation);
  Memory Curator-Rolle (`AGENTS.md` §3.14); Handover §7a (Gedächtnis-Übergabe).
- Konsum-/Vendor-Muster für Zielprojekte (Drei-Ebenen-Trennung) in `AGENTS.md` §0 / `README.md`.
- Ausführbare Beweise: `scripts/verify-proofs.sh` (ajv, gitleaks, TLC); konsolidierte
  TLA+-Konfiguration `specs/workflow.cfg`.

## [1.0.0] — Basis

### Added
- Verfassung `AGENTS.md` (9 Gesetze), `workflow-cfg.md` (CFG + Terminierungs-/Deadlock-Beweis),
  `tools-registry.md`, `handover-template.md`, JSON-Schema, TLA+-Spezifikation, Templates.
