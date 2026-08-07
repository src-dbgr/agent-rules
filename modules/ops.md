# Betrieb — Resume, Approval, Beobachtbarkeit, Kosten

> Normativ für `LAW-OPS`. Schließt die Profi-Lücken um lange Sessions, Geld und
> irreversible Schritte — ohne den Main-Thread aufzublähen.

Zahlen: `config/policy-defaults.json` (`ops`, `budgets`).

## 1. Assignment-Ledger (wer macht was) {#ledger}

Der Orchestrator führt im State `assignments[]`. Jede Delegation hat:

| Feld | Bedeutung |
|------|-----------|
| `task_id` | **UUID** der Aufgabe (Korrelations-ID) |
| `agent_id` | ID des Sub-Agenten |
| `role` | Rolle |
| `cfg_node` | Knoten |
| `handover_out_id` | Handover Orchestrator → Agent |
| `handover_return_id` | Handover zurück (sobald da) |
| `parent_task_id` | optional, bei Unter-Delegation |
| `write_paths` | erlaubte Schreibpfade (disjunkt bei Parallelität) |
| `status` | `open` \| `running` \| `returned` \| `failed` \| `cancelled` |
| `model_id` | gewähltes Modell (`LAW-MODELS`) |

**UUID-Sinn:** Ja — `task_id` verknüpft Auftrag, Agent, Handover-Hin und -Rück,
ohne den Main-Thread die Volltexte lesen zu müssen. Kurz-IDs für Agenten bleiben
erlaubt; **Aufgaben** sind UUIDs (Kollisionsfreiheit über Sessions).

Regel: Eine Rückgabe ohne passende `task_id` / `handover_out_id` wird **abgewiesen**
(nicht still aggregiert). Parallelität nur bei disjunkten `write_paths`.

## 2. Resume nach Pause/Crash {#resume}

Wiederaufnahme:

1. Lock prüfen (`state-lock.sh`); fremder Lock → `t_blocked`.
2. State laden; `phase` und `cfg.active_node` sind maßgeblich.
3. **GC:** `scripts/gc-sweep.sh --apply` — Scratch und abgelaufene Artefakte weg
   (kein Kontext-Müll aus der Vorgänger-Instanz).
4. Offene `assignments` mit `status=running` und fehlendem Return: entweder
   Timeout laut config → `failed` + Neu-Delegation, oder auf Return warten.
5. `awaiting_user` / `awaiting_continuation`: **keine** Implementation bis Antwort
   bzw. bis der neue Agent den Prompt übernommen hat.
6. Nie Archiv-Handovers als Wahrheit — nur State + Index + aktive Assignments.

## 3. Human-Approval bei `irrev` {#approval}

Vor Ausführung einer als `irrev` beflaggten Änderung:

- Orchestrator holt explizite Freigabe (`approval_token` im State oder Nutzerantwort).
- Ohne Token: `phase: awaiting_user`, kein `N4`/`N6b` für diesen Teil.
- Gilt auch für Prod-Deploy, Datenlöschung, Schema-Break.

## 4. Kosten- und Zeitbudget {#cost}

Zusätzlich zu Token-/Tool-Proxies (`LAW-CONTEXT`):

- `ops.max_wall_clock_minutes` je Lauf (Default siehe config)
- `ops.max_model_rank_default` (Aufstieg nur mit Begründung, `LAW-MODELS`)
- Effort-Caps je Klasse bleiben in `effort`

Überschreitung → Rotation, Downgrade-Modell, oder `t_blocked` mit Kostenvermerk —
kein stilles Weiterlaufen in Rank 5.

## 5. Beobachtbarkeit {#observability}

Append-only `runtime/audit.jsonl`, eine Zeile je Ereignis (kein Kontext-Bloat):

`ts`, `task_id`, `agent_id`, `event` (`spawn`|`return`|`escalate`|`gate_pass`|`gate_fail`|`clarify`|`approve`|`gc`), `node`, `bytes_ref`

Main-Thread liest **nicht** das ganze Log — nur bei Eskalation gezielt die letzte
relevante `task_id`.

## 6. Agent-Eval (Regression der Orchestrierung) {#eval}

Mindestgate vor Release des Gesetzbuchs / bei Änderung an Triage oder CFG:

- `scripts/check-triage.sh` (Algebra)
- Fixtures „Prompt-Signal → erwartete Klasse/Flags“ wo vorhanden
- Mutation der TLA+-Sonde muss scheitern (`specs/mutation.cfg`)

Das schützt den **Workflow** vor Regression — separat von Produkttests
(`modules/quality.md`).
