# Changelog — agent-rules (Gesetzbuch)

Alle nennenswerten Änderungen an diesem Gesetzbuch werden hier dokumentiert.
Das Regelwerk verlangt für jede Änderung eine **bewusste Versionserhöhung**
(`AGENTS.md` §8, `README.md`); dieses Changelog macht diese Historie nachvollziehbar
(Auditierbarkeit, vgl. `AGENTS.md` §3.12 Compliance/Governance).

Format angelehnt an [Keep a Changelog](https://keepachangelog.com/);
Versionierung semantisch (MAJOR.MINOR.PATCH) auf das Gesetzbuch als Ganzes.

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
