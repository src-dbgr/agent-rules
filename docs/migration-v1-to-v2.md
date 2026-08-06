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
| `workflows/triage-decision-matrix.md` | Stub → `modules/triage.md` |

## State migrieren

```bash
./scripts/migrate-state.sh runtime/state/<id>.json          # Dry-Run
./scripts/migrate-state.sh runtime/state/<id>.json --write  # Schreiben
```

## Zielprojekt umstellen

1. Vendor pullen: `cd .agent-rules && git pull`
2. Bootstrap-Prompt aus `prompts/project-bootstrap-prompt.md` verwenden
3. `runtime/` gitignorieren (kompletter Baum)
4. Optional: einmal `./scripts/gc-sweep.sh --apply` für Alt-Müll
5. Prüfen: `bash scripts/lint-lawbook.sh --all --strict`
