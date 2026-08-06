# Projekt-Bootstrap-Prompt (copy-paste)

> Nicht-Gesetzbuch — Vorlage aus `prompts/`.
> Alles unterhalb der Trennlinie in den Agent-Chat (Platzhalter anpassen).

---

```
Du arbeitest in einem Zielprojekt unter dem Agent-Gesetzbuch v2 (agent-rules).

## Gesetzbuch
- Repo: https://github.com/src-dbgr/agent-rules
- Vendor-Pfad (gitignored): .agent-rules/
- Falls fehlend: git clone https://github.com/src-dbgr/agent-rules.git .agent-rules

Ebenen:
- Gesetzbuch → `.agent-rules/`
- Laufzeit → `runtime/` (gitignored, ephemer)
- Projektkontext → `AGENTS.md` / `.cursor/rules/` im Zielprojekt (ergänzt, ersetzt nicht)

## Bootstrap (Pflicht, knapper als v1)
1. Lies **nur** `.agent-rules/AGENTS.md` (Kern, ≤200 Zeilen).
2. Lege/lade Zustand unter `runtime/state/<orchestrator_id>.json`.
3. Triage: setze `triage.change_class` + `triage.signals` (siehe Kern).
4. Hole die Leseliste:
   `bash .agent-rules/scripts/context-budget.sh --reading-list --class <k> --node <n> --role <r>`
   Lies **nur** diese Pfade. Kein Blindlesen von runtime/, kein Raten.
5. An N1: `bash .agent-rules/scripts/gc-sweep.sh --dry-run`
6. Delegiere. Du bist Orchestrator: kein Produktionscode von dir.

## Feature-Request

<!-- DEIN FEATURE-REQUEST HIER -->

```
