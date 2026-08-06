# Kontext — Hierarchie, Budget, Rotation, Delegation

> Normativ für `LAW-HIERARCHY`, `LAW-LINEAGE`, `LAW-DELEGATION`, `LAW-ROLES`,
> `LAW-ISOLATION`, `LAW-CONTEXT`. Zahlen ausschließlich in `config/policy-defaults.json`.

## Hierarchie {#hierarchie}

1. Empfänger der Nutzeranfrage ist Orchestrator (Tiefe 0). Er schreibt keinen
   Produktionscode; er pflegt Zustand, Handover, Aufträge und die Nutzerantwort.
2. Sub-Agenten bilden einen Baum; maximale Tiefe steht in `budgets.max_depth`.
3. Auf maximaler Tiefe: Lösung liefern, Problem abstrahieren und zurückgeben,
   oder Hard Error. Kein stiller Abbruch, kein weiterer Spawn.
4. Fan-out je Agent: `budgets.max_fanout`. Global: `budgets.max_total_spawned`.

## Amtsübergabe {#amtsuebergabe}

Je Anfrage-Baum ist genau ein Orchestrator aktiv (`LAW-LINEAGE`). Bei
Kontext-Rotation des Orchestrators:

1. Neuer Agent derselben Rolle, gleiche Tiefe; **kein** Spawn-Zähler-Inkrement.
2. Eintrag in `orchestrator_lineage[]` (alt → neu, Grund, Zeitstempel).
3. Zustandspfad bleibt `runtime/state/<orchestrator_id>.json` (ID der Wurzel).
4. Lock wird übergeben (`scripts/state-lock.sh`).

## Budget {#budget}

`context_utilization_percent` ist **kein** Pflichtauslöser. Steuerung über
zählbare Proxies in `budget` (Felder laut Schema):

| Proxy | Schwellwert (config) | Aktion |
|-------|----------------------|--------|
| `bytes_read` | `budgets.rotation.bytes_read_max` | Rotation |
| `files_read` | `budgets.rotation.files_read_max` | Rotation |
| `tool_calls` | `budgets.rotation.tool_calls_max` | Rotation |
| `turns` | `budgets.rotation.turns_max` | Rotation |
| `artifact_bytes` | `budgets.rotation.artifact_bytes_max` | Rotation |

`utilization_percent` (Default `percent_backstop`) ist nur Backstop: Warnung,
kein automatischer Zwang. Lesebudget je Delegation / Lauf:
`caps.read_bytes_per_delegation_max` / `caps.read_bytes_per_run_max`.

Messung: `scripts/context-budget.sh --check` gegen den Zustand. Schätzung
ohne Zähler ist verboten.

## Leseliste {#leseliste}

```
./scripts/context-budget.sh --reading-list --class <k> --node <n> --role <r>
```

Ausgabe: Pfade und Anker, Reihenfolge verbindlich. Agent liest **nur** das.
Quelle: `manifest.json#/reading_lists`. Improvisierte Pfade → Blocker + `t_blocked`.

## Isolation {#isolation}

Ein Sub-Agent erhält genau:

1. diesen Kern (`AGENTS.md`),
2. eine Rollen-Karte `roles/<rolle>.md`,
3. sein Handover,
4. die Anker seiner Leseliste.

Verboten: Elternhistorie, Geschwister-Handover, Archiv-Scan, blindes
`runtime/`-Auflisten (`LAW-LIFECYCLE`).

## Delegationsbrief {#delegationsbrief}

Jede Delegation / Rückgabe / Eskalation / Rotation ist ein Handover
(`templates/handover.md`, Schema `schemas/handover.schema.json`). Pflicht:

- globales Ziel unverändert,
- CFG-Knoten und DoD,
- Artefakt-**Pfade** (keine Inline-Logs),
- exakter Startpunkt für den Empfänger,
- Rückgabe ≤ `caps.subagent_return_max_lines` Zeilen.

Format und Retention: `modules/lifecycle.md#handover`.

## Rotation {#rotation}

Erreicht ein Proxy seinen Schwellwert:

1. Atomare Teilaufgabe abschließen.
2. Handover `handover_type: context_rotation` an gleiche Rolle/Tiefe.
3. `cycles.rotations` erhöhen; Grenze `budgets.max_rotations_per_task`.
4. Nach Rotation: Kern erneut lesen (`LAW-CONTEXT`).

Rotation zählt **nicht** gegen `tree.total_spawned`.
