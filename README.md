# agent-rules

Executable ruleset for multi-agent software work. One core file (`AGENTS.md`)
is mandatory; modules and role cards load on demand under a counted context
budget. A gate passes only with an executed proof. SKIP (exit 2) is never PASS.

**2.1.0** adds a one-page program design before production code, vertical
slices with a check command each, and human plan review only on elevated
feature work. State schema stays `2.0.0`.

The normative German text below is unchanged. Read `AGENTS.md` next.

```bash
git clone https://github.com/src-dbgr/agent-rules.git
bash scripts/lint-lawbook.sh --all --strict
bash scripts/context-budget.sh --reading-list --class chore --node N2 --role developer
bash scripts/check-triage.sh
bash scripts/verify-proofs.sh
```

## Deutsch — Gesetzbuch

> **Version:** 2.1.1  
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

## Was 2.1.0 ergänzt

| 2.0.1 | 2.1.0 |
|-------|-------|
| Produktionscode kann sofort starten | Ein-Seiten-Plan zuerst; ohne bestandenen Plan kein Produktionscode |
| Kein Halt am Plan | Halt nur bei Feature plus Sicherheit, Architektur, Nebenläufigkeit, Daten oder Unumkehrbarkeit |
| Umsetzung als ein Block | Vertikale Scheiben; je Scheibe ein ausgeführtes Prüfkommando |
| 10 Tool-Calls, 120 000 Bytes Lesen | 20 Calls je Agent, 250 000 Bytes, eigener Recherche-Zuschlag |

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

20 benannte IDs (`LAW-HIERARCHY` … `LAW-OPS`) — Tabelle in `AGENTS.md`.
Details nur in den genannten Modulen (Single Source of Truth).

## Lizenz

MIT — siehe `LICENSE`. Änderungen brauchen Versions-Bump und `CHANGELOG.md`.
