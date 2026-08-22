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
| `created_at` | Start der Delegation |
| `last_progress_at` | letzter Fortschrittsimpuls (Pflicht solange `running`) |
| `progress_note` | optional, ≤120 Zeichen (was zuletzt vorankam) |

**UUID-Sinn:** Ja — `task_id` verknüpft Auftrag, Agent, Handover-Hin und -Rück,
ohne den Main-Thread die Volltexte lesen zu müssen. Kurz-IDs für Agenten bleiben
erlaubt; **Aufgaben** sind UUIDs (Kollisionsfreiheit über Sessions).

Regel: Eine Rückgabe ohne passende `task_id` / `handover_out_id` wird **abgewiesen**
(nicht still aggregiert). Parallelität nur bei disjunkten `write_paths`.

Sub-Agenten **müssen** bei sinnvoller Teilarbeit `last_progress_at` aktualisieren
(Kurz-Handover, Audit-Ereignis `progress`, oder Ledger-Patch durch Orchestrator nach
Statusmeldung). Schweigen ≠ Fortschritt.

## 1a. Stall-Watchdog (hängende Sub-Agenten) {#stall}

Der Main-Thread wartet nicht blind. Für jedes `assignments[]`-Item mit
`status=running`:

1. **Stall:** `now - last_progress_at` (sonst `created_at`) ≥
   `ops.assignment_stall_minutes` (Default siehe config) → Assignment `failed`,
   Audit-Ereignis `stall`, Begründung „kein Fortschritt“.
2. **Hard-Timeout:** `now - created_at` ≥ `ops.assignment_running_timeout_minutes`
   → ebenfalls `failed` (auch mit sporadischem Progress, wenn die Gesamtdauer reißt).
3. **Reaktion:** höchstens `ops.max_stall_retries` Neu-Delegation derselben
   `task_id`-Linie (neues Assignment, `parent_task_id` gesetzt) **oder** Eskalation
   an den Nutzer / `t_blocked`. Kein stilles Endloswarten.
4. **Wann prüfen:** vor jeder Aggregation, vor Spawn weiterer Geschwister auf derselben
   Ressource, bei Resume (`§2`), und sobald der Orchestrator wieder am Zug ist
   (keine Hintergrund-Daemon-Pflicht im Chat — aber **kein** „ich ignoriere running“).

Stall ist kein Beweis für Modellschwäche allein; erst Retry/Eskalation mit kurzem Vermerk.

## 2. Resume nach Pause/Crash {#resume}

Wiederaufnahme:

1. Lock prüfen (`scripts/state-lock.sh`); fremder Lock → `t_blocked`.
2. State laden; `phase` und `cfg.active_node` sind maßgeblich.
3. **GC:** `scripts/gc-sweep.sh --apply` — Scratch und abgelaufene Artefakte weg
   (kein Kontext-Müll aus der Vorgänger-Instanz).
4. Offene `assignments` mit `status=running`: Stall-/Timeout-Regeln aus `§1a` anwenden
   (`failed` + Retry/Eskalation); nicht unbegrenzt auf Return warten.
5. `awaiting_user` / `awaiting_continuation`: **keine** Implementation bis Antwort
   bzw. bis der neue Agent den Prompt übernommen hat.
6. Nie Archiv-Handovers als Wahrheit — nur State + Index + aktive Assignments.

## 3. Human-Approval bei `irrev` und Plan {#approval}

Vor Ausführung einer als `irrev` beflaggten Änderung **oder** sobald
`dod:human_plan_review` in Gates steht:

- Orchestrator holt explizite Freigabe (`approvals[]` im State oder Nutzerantwort).
- Ohne Token: `phase: awaiting_user`, kein `N4`/`N6b` für diesen Teil.
- Bei Plan-Review: Kurzfassung des Programmentwurfs (eine Seite) vorlegen, nicht den
  gesamten Diff. Scope im Approval: `plan_review` bzw. `irrev`.
- Gilt auch für Prod-Deploy, Datenlöschung, Schema-Break.
- `feature` ohne die Flags aus `human_plan_review_on_flags`: Plan vorlegen, **nicht** warten.

## 4. Kosten- und Zeitbudget {#cost}

Zusätzlich zu Token-/Tool-Proxies (`LAW-CONTEXT`):

- `ops.max_wall_clock_minutes` je Lauf (Default siehe config)
- `ops.max_model_rank_default` (Aufstieg nur mit Begründung, `LAW-MODELS`)
- Effort-Caps je Klasse bleiben in `effort`

Überschreitung → Rotation, Downgrade-Modell, oder `t_blocked` mit Kostenvermerk —
kein stilles Weiterlaufen in Rank 5.

## 5. Beobachtbarkeit {#observability}

Append-only `runtime/audit.jsonl`, eine Zeile je Ereignis (kein Kontext-Bloat):

`ts`, `task_id`, `agent_id`, `event` (`spawn`|`return`|`escalate`|`gate_pass`|`gate_fail`|`clarify`|`approve`|`gc`|`progress`|`stall`), `node`, `bytes_ref`

Main-Thread liest **nicht** das ganze Log — nur bei Eskalation gezielt die letzte
relevante `task_id`.

## 6. Agent-Eval (Regression der Orchestrierung) {#eval}

Mindestgate vor Release des Gesetzbuchs / bei Änderung an Triage oder CFG:

- `scripts/check-triage.sh` (Algebra)
- Fixtures „Prompt-Signal → erwartete Klasse/Flags“ wo vorhanden
- Mutation der TLA+-Sonde muss scheitern (`specs/mutation.cfg`)

Das schützt den **Workflow** vor Regression — separat von Produkttests
(`modules/quality.md`).
