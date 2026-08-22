# Changelog — agent-rules (Gesetzbuch)

Alle nennenswerten Änderungen an diesem Gesetzbuch werden hier dokumentiert.
Das Regelwerk verlangt für jede Änderung eine **bewusste Versionserhöhung**
(`AGENTS.md` §8, `README.md`); dieses Changelog macht diese Historie nachvollziehbar
(Auditierbarkeit, vgl. `AGENTS.md` §3.12 Compliance/Governance).

Format angelehnt an [Keep a Changelog](https://keepachangelog.com/);
Versionierung semantisch (MAJOR.MINOR.PATCH) auf das Gesetzbuch als Ganzes.

## [2.1.0] — 2026-08-22

### Added
- `dod:program_design` for class `feature` and flags `arch`/`conc`/`data`/`irrev`: one-page plan (file tree, signatures, vertical slices with a check command each) before `N4`.
- `dod:human_plan_review` for `feature` plus an elevated flag (`arch`/`conc`/`sec`/`data`/`irrev`): present the plan and wait (`awaiting_user`). Other classes do not wait.
- `effort.n3a` bonus so research does not immediately hit the class cap.
- Model-policy `user_override`: named model request may lift a `never` entry; platform blocks (Fable retention ack) must be stated, never silently swapped.

### Changed
- `N4` DoD: implement in vertical slices; in-slice retries do not increment `test_fix`.
- Effort is per agent; `effort.answer.max_tool_calls` 10 → 20.
- `caps.read_bytes_per_run_max` 120000 → 250000 (a single real research source already exceeded the old cap).
- Approval (`modules/ops.md#approval`) covers plan review as well as `irrev`.
- Handover templates match `schemas/handover.schema.json`; `validate-handovers.sh` parses nested YAML.

### Unchanged (bewusst)
- Flag algebra still one Zusatz-Gate per flag (High-Water-Mark). SKIP ≠ PASS. Isolation, VCS bans, Quality anti-bloat.

## [2.0.1] — 2026-08-15

### Changed
- README opens with an English lead (what / why / five commands / `AGENTS.md`). German text stays below.
- `lawbook-ci` must be green: no “intentionally red / WP-2..WP-6 open” framing; no `continue-on-error` on proof steps. SKIP / exit 2 still fails the job. `--allow-skip` remains forbidden in CI.
- Linter recognizes explicit `{#anchor}` IDs; manifest entries for v2 modules/config/prompts are schema-complete; `LAW-CLARIFY`…`LAW-OPS` have `rule` + `normative_in`; policy schema covers `clarification`/`ops`. Empty ADR/review globs and the superseded triage-fixtures path are optional.

### Unchanged (bewusst)
- `LAW-*` texts, modules (except missing anchors / one phase name / one script path), role cards (except `business_analyst` heading `Rückgabeformat`), triage algebra, state schema `2.0.0`, TLA+ model.

## [2.0.0] — 2026-08-06

### Breaking
- Bootstrap-Pflichtlektüre: nur noch `AGENTS.md` (≤200 Zeilen). Alte 5-Datei-Bootstrap-Pflicht entfällt.
- Triage: Tracks `fast`/`standard`/`deep` und `complexity_score` ersetzt durch 6 Klassen
  (`answer`/`chore`/`revert`/`spike`/`incident`/`feature`) + 9 Flags; ein Verfahren.
- Gesetzes-IDs: benannte `LAW-*` statt kollidierender Nummern.
- CFG: eine Knotenzählung (`N0…N7` mit `a/b/c`); erweiterte N8–N12-Nummerierung entfällt.
- State-Schema `2.0.0`; Migration: `scripts/migrate-state.sh`.
- Laufzeit: `runtime/` vollständig ephemer; Handovers unter `runtime/handovers/` mit Index + GC.
- Nachweis-Semantik: SKIP / fehlendes Tool = Exit 2, nie PASS.

### Added
- `modules/*` (on-demand), `roles/*` (Karten), `manifest.json`, `config/policy-defaults.json`.
- Skripte: `scripts/lint-lawbook.sh`, `scripts/context-budget.sh`, `scripts/gc-sweep.sh`, `scripts/branch-hygiene.sh`,
  `scripts/check-triage.sh`, `scripts/validate-handovers.sh`, `scripts/state-lock.sh`, `scripts/snapshot.sh`, CI-Workflow.
- `docs/migration-v1-to-v2.md`, MIT `LICENSE`.
- **`LAW-CLARIFY`** + `modules/clarification.md`: Pflicht-Rückfragen bei blockierender Unsicherheit; Anti-Pseudo-Fragen; Phase `awaiting_user`.
- **`LAW-MODELS`** + `config/model-policy.json`
- **`LAW-QUALITY`** + `modules/quality.md`: Regression by Design, Test-Disziplin (kein Suite-Bloat)
- **`LAW-ASSIGN`/`LAW-OPS`** + `modules/ops.md`: Assignment-Ledger mit task_id (UUID), Resume, irrev-Approval, Kosten, Audit-Log: konfigurierbare LLM-Leiter und Never-Liste (kein Hardcode in AGENTS.md).
- Main-Thread Context-Clean-Abschnitt in `AGENTS.md`.

### Changed
- Alte Top-Level-Normdateien sind Kompatibilitäts-Stubs (≤10 Zeilen) mit Verweis.
- Bootstrap-Prompt und README auf v2 umgestellt.
- Knoten in `modules/workflow.md` mit Klartext-Namen (Eingang/Start/Einordnung/…).
- `templates/handover-filled-example.md` und [`templates/skill-template/SKILL.md`](templates/skill-template/SKILL.md) auf v2-Sprache/`task_id` gezogen.
- UI-Qualität (`modules/quality.md#ui`): Playwright-/E2E schmal bei Flag `ui`; bildbasiertes Agent-Review bei komplexer UI; Verifikations-Screenshots nur ephemer (`proof-artifacts/` / `runtime/tmp/`), nie committen.
- Architektur-Kern in `modules/quality.md#by-design`: SOLID-Kurzabsatz (SoC/SRP/ISP/DIP, keine Zyklen; optionale Cycle-Tools nur im Zielprojekt).
- **Model-Policy v1.1:** Main-Thread/Orchestrator (`N0`–`N2`, `N7`) startet verpflichtend mit `grok-4.5-high` (`entry_points.orchestrator_main_thread`); Composer bleibt Standard für Coding-Sub-Agenten. Begründung: Triage-Algebra ist deterministisch, Erst-Klassifikation nicht (A-12).
- **Stall-Watchdog** (`modules/ops.md#stall`): `last_progress_at`; Stall nach `assignment_stall_minutes` (15); Hard-Timeout 90; max. 1 Retry — Main-Thread wartet nicht endlos auf hängende Sub-Agenten.
- **Mini-Tasks:** nach Pflicht-Triage leichte Klassen `answer`/`chore` (nicht vorschnell `feature`); Effort-Caps bleiben führend.

### Removed
- Root-State-Datei (`<.agent-state.json>`) (verbotener Legacy-Pfad; Beispiel nur noch unter `examples/`).
- `<workflows/triage-decision-matrix.md>` (ersetzt durch `modules/triage.md`).
- `<proofs/termination-proof.md>` (ersetzt durch `modules/workflow.md` (Rank-Funktion) + `specs/coverage.md`).
- `<templates/handover-example.md>` (veraltetes Doppelbeispiel).

## [1.3.1] — 2026-07-06

### Added
- **`cycles.one_shot_escalations`** in `schemas/agent-state.schema.json`: maschinenlesbare
  Boolean-Flags für die One-shot-Rückkanäle **N5 → N3b** (`requirements_gap_n5_n3b`)
  und **N5 → N3c** (`architecture_drift_n5_n3c`), die in v1.3.0 als Gesetz definiert,
  aber nicht schema-seitig erzwungen waren.
- **`cycles.loop_history`** erweitert: `loop`-Enum um `requirements_escalation` und
  `architecture_escalation`; optionale Felder `from_node`/`to_node` für Audit-Trail.

### Changed
- `workflow-cfg.md` §5.3 (One-shot-Eskalations-Tracking), §8 Orchestrator-Pflichten;
  `AGENTS.md` Gesetz-2-Zykluslimit und Gesetz-4-Zustandsfeld-Tabelle;
  `<proofs/termination-proof.md>` §7 (Laufzeit-Enforcement-Hinweis).
- Versions-Bump aller Kerndokumente auf **1.3.1** (`AGENTS.md`, `README.md`,
  `workflow-cfg.md`, `memory-policy.md`, `skills-policy.md`, `tools-registry.md`,
  `handover-template.md`, `<workflows/triage-decision-matrix.md>`,
  `<proofs/termination-proof.md>`).
- `schemas/agent-state.schema.json` (`schema_version` const) und alle Instanzen/Beispiele
  (`<.agent-state.json>`, `handover-template.md`, `templates/handover-filled-example.md`) auf
  `1.3.1` gehoben.

### Unchanged (bewusst)
- **`specs/workflow.tla` / `specs/workflow.cfg` nicht geändert:** One-shot-Eskalationen
  bleiben im TLA+-Modell als knoten-lokale, endliche Aktionen abstrahiert; die neuen
  Schema-Flags sind Laufzeit-Enforcement für Orchestrator/Engine, keine Topologieänderung
  (`<proofs/termination-proof.md>` §7).

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
  `<workflows/triage-decision-matrix.md>` (Rollen-Ketten, Anti-Overengineering-Regel 4).
- Versions-Bump aller Kerndokumente auf **1.3.0** (`AGENTS.md`, `README.md`,
  `workflow-cfg.md`, `memory-policy.md`, `skills-policy.md`, `tools-registry.md`,
  `handover-template.md`, `<workflows/triage-decision-matrix.md>`,
  `<proofs/termination-proof.md>`).
- `schemas/agent-state.schema.json` (`schema_version` const) und alle Instanzen/Beispiele
  (`<.agent-state.json>`, `handover-template.md`, `templates/handover-filled-example.md`) auf
  `1.3.0` gehoben. **Keine strukturelle Schemaänderung** — nur Versionskennung.

### Unchanged (bewusst)
- **`specs/workflow.tla` / `specs/workflow.cfg` nicht geändert:** Der neue
  Rückkanal N5 → N3c ist **one-shot** (max 1×) und wird — wie das bereits
  bestehende N5 → N3b — im formalen Modell als knoten-lokale, endliche Aktion
  abstrahiert. Die geprüften Invarianten (`InvCycle` `cycle ≤ 3`, `InvDepth`
  `depth ≤ 4`, `InvTerminal`) und der Terminierungs-/Deadlock-Beweis bleiben
  unverändert gültig (Begründung: `workflow-cfg.md` §6.3, `<proofs/termination-proof.md>` §7).
  Die CFG-Topologie ändert sich damit **nicht materiell**.

## [1.2.0] — 2026-07-06

### Added
- **`skills-policy.md`** — verbindliche Governance für **Agent Skills** (SKILL.md-Datei):
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
  `<workflows/triage-decision-matrix.md>`, `<proofs/termination-proof.md>`).
- Querverweise auf `skills-policy.md` ergänzt in `AGENTS.md` (§3.14, §9 Quellen),
  `README.md` (Struktur + Skills-Abschnitt), `memory-policy.md` (§1, §7, §8-Cursor-Tabelle)
  und `tools-registry.md` (§3.9).
- `schemas/agent-state.schema.json` (`schema_version` const) und alle Instanzen/Beispiele
  (`<.agent-state.json>`, `handover-template.md`, `templates/handover-filled-example.md`) auf
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
