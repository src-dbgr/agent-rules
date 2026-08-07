# Migration v1.3.1 → v2.0.0

Kurz: Bootstrap liest **nur noch** `AGENTS.md` (≤200 Zeilen). Alles andere
wird über `scripts/context-budget.sh --reading-list` geladen.

## Was sich ändert

| v1 | v2 |
|----|----|
| Pflichtlektüre 5 Dateien (~2000 Z.) | 1 Datei (`AGENTS.md`) |
| Tracks `fast`/`standard`/`deep` | Klassen `answer`/`chore`/`revert`/`spike`/`incident`/`feature` + Flags |
| `complexity_score` | entfällt |
| Knoten N0–N7 und N0–N12 gemischt | eine Zählung `N0…N7` mit `a/b/c` |
| Gesetze als Nummern (kollidierend) | `LAW-*` IDs |
| `runtime/handover-*.md` flach | `runtime/handovers/`, Index, GC |
| kein Branch-Abräumen | `scripts/branch-hygiene.sh` |
| SKIP = PASS möglich | SKIP = Exit 2, nie PASS |

## Alt → Neu (Dateien)

| Alt | Neu |
|-----|-----|
| `AGENTS.md` (monolithisch) | `AGENTS.md` (Kern) + `modules/*` + `roles/*` |
| `workflow-cfg.md` | Stub → `modules/workflow.md` |
| `tools-registry.md` | Stub → `modules/tools.md` |
| `handover-template.md` | Stub → `templates/handover.md` + `modules/lifecycle.md` |
| `memory-policy.md` | Stub → `modules/memory.md` |
| `skills-policy.md` | Stub → `modules/skills.md` |
| `.gitignore` | beibehalten / erweitert (`runtime/`, `states/`, …) |
| `CHANGELOG.md` | fortgeschrieben |
| `README.md` | auf v2 umgestellt |
| `prompts/README.md` | fortgeschrieben |
| `prompts/project-bootstrap-prompt.md` | auf v2 umgestellt |
| `schemas/agent-state.schema.json` | Schema `2.0.0` |
| `scripts/verify-proofs.sh` | beibehalten (TLA+/Coverage) |
| `specs/workflow.cfg` / `specs/workflow.tla` | beibehalten; Norm-Beweis in `modules/workflow.md` (Rank-Funktion) + `specs/coverage.md` |
| `templates/handover-filled-example.md` | auf v2-Template/`task_id` gezogen |
| `templates/skill-template/SKILL.md` | Verweise auf `modules/skills.md` |

## Gelöscht (kein Stub — Inhalt ersetzt oder Altlast)

| Datei | Grund |
|-------|-------|
| `<.agent-state.json>` | Live-/Beispiel-State im Root verboten; Ersatz: `examples/agent-state.example.json` und `runtime/state/<id>.json` |
| `<workflows/triage-decision-matrix.md>` | Scoring-Matrix ersetzt durch `modules/triage.md` (nicht verschoben) |
| `<proofs/termination-proof.md>` | ersetzt durch Rank-Argument in `modules/workflow.md` plus `specs/coverage.md` |
| `<templates/handover-example.md>` | veraltetes Doppelbeispiel; kanonisch: `templates/handover.md` + `templates/handover-filled-example.md` |

Kompatibilitäts-Stubs (kurz, mit Verweis) bleiben: `workflow-cfg.md`, `tools-registry.md`,
`memory-policy.md`, `handover-template.md`, `skills-policy.md`.

## State migrieren

```bash
./scripts/migrate-state.sh runtime/state/<id>.json          # Dry-Run
./scripts/migrate-state.sh runtime/state/<id>.json --write  # Schreiben
```

## Zielprojekt umstellen

1. Vendor pullen: `cd .agent-rules && git pull`
2. Bootstrap-Prompt aus `prompts/project-bootstrap-prompt.md` verwenden
3. `runtime/` gitignorieren (kompletter Baum); Root-State-Datei (`<.agent-state.json>`) nicht anlegen
4. Optional: einmal `./scripts/gc-sweep.sh --apply` für Alt-Müll
5. Prüfen: `bash scripts/lint-lawbook.sh --all --strict`
