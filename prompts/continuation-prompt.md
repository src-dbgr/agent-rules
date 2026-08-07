# Fortsetzungs-Prompt (copy-paste) — frischer Kontext

> Nicht-Gesetzbuch — Vorlage. Der laufende Agent **gibt** diesen Block aus
> (oder `scripts/emit-continuation-prompt.sh` füllt ihn). Du kopierst alles
> zwischen den äußeren ` ``` `-Zäunen in einen **neuen** Agent-Chat.

---

```
Du setzt einen laufenden Agent-Auftrag mit FRISCHEM Kontext fort (Kontext-Handoff).

## Gesetzbuch (Pflicht zuerst)
- Vendor-Pfad: .agent-rules/  (sonst: git clone https://github.com/src-dbgr/agent-rules.git .agent-rules)
1. Lies NUR .agent-rules/AGENTS.md (Kern).
2. Du bist der NEUE Orchestrator (Amtsübergabe). Alte Instanz ist erschöpft.
3. Lade State: runtime/state/{{orchestrator_id}}.json
   (Lock: scripts/state-lock.sh --acquire --holder <deine-neue-id> --id {{orchestrator_id}})
4. Trage dich in orchestrator_lineage[] ein (von {{previous_orchestrator_id}} → du).
5. Leseliste nur über:
   bash .agent-rules/scripts/context-budget.sh --reading-list --class {{change_class}} --node {{active_node}} --role orchestrator
6. GC: bash .agent-rules/scripts/gc-sweep.sh --apply
   (Scratch/Abgelaufenes weg; Index prüfen. Danach weiter am State.)
7. Modellwahl: .agent-rules/config/model-policy.json
8. Assignment-Ledger (assignments[]) und offene task_ids sind maßgeblich — keine Archiv-Handovers lesen.

## Auftrag (unverändert)
{{original_user_prompt}}

## Wo du weitermachst
- phase: {{phase}}
- cfg.active_node: {{active_node}}
- triage.change_class: {{change_class}}
- triage.signals: {{signals}}
- Offene assignments (task_id → status): {{assignments_summary}}
- Letzte Kurz-Erkenntnisse (keine Volltexte): {{findings_bullets}}
- Nächster imperativer Schritt: {{next_step}}

## Harte Regeln
- Kein Produktionscode von dir; Sub-Agenten arbeiten; Rückgaben ≤150 Zeilen.
- LAW-CLARIFY / LAW-QUALITY / LAW-ASSIGN / LAW-OPS gelten.
- Bei erneut ~60% Kontext: WARNUNG an Nutzer; bei ~70%: wieder diesen Prompt ausgeben und STOPPEN.

## Handoff-Metadaten
- handoff_reason: context_exhaustion
- previous_budget_snapshot: {{budget_json}}
- created_at: {{created_at}}
```
