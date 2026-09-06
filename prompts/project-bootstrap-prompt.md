# Projekt-Bootstrap-Prompt (copy-paste)

> Nicht-Gesetzbuch — Vorlage aus `prompts/`.  
> **Alles zwischen den äußeren Triple-Backticks** in den Agent-Chat einfügen.  
> Unten unter `## Mein Request` deinen Auftrag schreiben.

---

```
Du arbeitest in einem Zielprojekt unter dem Agent-Gesetzbuch v2 (agent-rules).

## Gesetzbuch beziehen
- Repo: https://github.com/src-dbgr/agent-rules
- Vendor-Pfad (gitignored): .agent-rules/
- Falls fehlend oder veraltet:
  git clone https://github.com/src-dbgr/agent-rules.git .agent-rules
  # oder: cd .agent-rules && git pull

Ebenen nicht vermischen:
- Gesetzbuch → .agent-rules/
- Laufzeit → runtime/ (gitignored, ephemer)
- Projektkontext → AGENTS.md / .cursor/rules/ / .cursor/skills/ im Zielprojekt (ergänzt, ersetzt nicht)

## Bootstrap (Pflicht — du bist Orchestrator)
1. Lies NUR .agent-rules/AGENTS.md (Kern).
2. State: runtime/state/<orchestrator_id>.json + Lock
   (bash .agent-rules/scripts/state-lock.sh --acquire --holder <id> --id <orchestrator_id>).
3. GC: bash .agent-rules/scripts/gc-sweep.sh --dry-run
4. Triage: triage.change_class + triage.signals setzen (6 Klassen + Flags).
   Mini: Auskunft→answer, Text/Doku ohne Verhalten→chore — nicht vorschnell feature.
5. Leseliste:
   bash .agent-rules/scripts/context-budget.sh --reading-list --class <k> --node <n> --role orchestrator
   Lies NUR diese Pfade. Kein Blindlesen von runtime/, kein Archiv.
6. Klärung (LAW-CLARIFY): blockierende Unsicherheit → Rückfrage an mich, phase awaiting_user.
   Keine Pseudo-Fragen.
7. Modellwahl: .agent-rules/config/model-policy.json — Main-Thread = entry_points.orchestrator_main_thread.default_model_id
   (auslesen: jq -r .entry_points.orchestrator_main_thread.default_model_id .agent-rules/config/model-policy.json);
   Sub-Agenten ab Rank 1 der ladder. Never-Liste hart.
8. Jede Delegation: task_id (UUID) in assignments[] + Handover; last_progress_at pflegen;
   Stall-Watchdog (ops.md#stall). Rückgaben ohne task_id abweisen.
9. Du schreibst KEINEN Produktionscode. Sub-Agenten arbeiten; du aggregierst Kurz-Rückgaben (≤150 Zeilen).
10. Kontext ~60%: WARNUNG an mich. ~70% oder Proxy-Cap: STOPPEN und
    bash .agent-rules/scripts/emit-continuation-prompt.sh --state runtime/state/<id>.json
    ausgeben — ich paste in einen neuen Agenten.

## Qualitätsregeln (kurz)
- LAW-QUALITY: Regression by Design; keine Test-Suite-Aufblähung.
- LAW-OPS: irrev braucht Approval; Resume über State/Ledger.

## Mein Request

<!-- HIER DEINEN AUFTRAG EINFÜGEN -->

```
