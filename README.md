# agent-rules — Gesetzbuch für Agenten-gesteuerte Software-Projekte

> **Version:** 2.0.0  
> **Status:** Verbindlich (normativ)

Verfassung für Multi-Agenten-Arbeit: Hierarchie, Triage, Delegation, DoD mit
ausführbaren Nachweisen. **v2** ist eine Kontext-Diät gegenüber v1.3.x.

## Was v2 ändert (Kern)

| Problem v1 | Lösung v2 |
|------------|-----------|
| Bootstrap ~2000 Zeilen / Agent | Nur `AGENTS.md` ≤200 Zeilen; Rest on-demand |
| 3 Tracks, zwei Scorings | 6 Klassen + 9 Flags, ein Verfahren |
| Handover-/Runtime-Müll | Retention + GC (`scripts/gc-sweep.sh`) |
| Branches bleiben liegen | Report + Dry-Run (`scripts/branch-hygiene.sh`) |
| SKIP zählte als PASS | Exit 2 = nicht nachgewiesen |

## Schnellstart

1. Lies **`AGENTS.md`** (einzige Pflichtlektüre).
2. Triage: Klasse + Flags setzen.
3. Leseliste: `bash scripts/context-budget.sh --reading-list --class <k> --node <n> --role <r>`
4. Delegieren mit `templates/handover.md`.
5. Prüfen: `bash scripts/lint-lawbook.sh --all --strict`

Migration von v1: [`docs/migration-v1-to-v2.md`](docs/migration-v1-to-v2.md).  
Copy-paste Prompt: [`prompts/project-bootstrap-prompt.md`](prompts/project-bootstrap-prompt.md).

## Struktur

```
AGENTS.md                 # Kern (Pflicht)
modules/                  # On-demand (workflow, triage, context, lifecycle, …)
roles/                    # Eine Karte je Rolle
config/policy-defaults.json
manifest.json             # Struktur-SSoT + Leselisten
schemas/                  # State, Handover, Manifest, Policy
scripts/                  # lint, triage, gc, budget, branch-hygiene, …
templates/handover.md
docs/migration-v1-to-v2.md
```

Alte Top-Level-Dateien (`workflow-cfg.md`, …) sind **Stubs** mit Verweis.

## Konsum im Zielprojekt

```bash
git clone https://github.com/src-dbgr/agent-rules.git .agent-rules
```

`runtime/` und `.agent-rules/` gitignorieren. Runtime ist ephemer.

## Gesetze (Kurz)

15 benannte IDs (`LAW-HIERARCHY` … `LAW-DELIVERY`) — Tabelle in `AGENTS.md`.
Details nur in den genannten Modulen (Single Source of Truth).

## Lizenz

MIT — siehe `LICENSE`. Änderungen brauchen Versions-Bump und `CHANGELOG.md`.
