---
handover_id: hv-xxxx
task_id: "00000000-0000-4000-8000-000000000000"
parent_agent_id: orc-xxxx
agent_id: sub-xxxx
role: developer
depth: 1
node: N4
class: feature
flags: []
reason: delegation
goal: "Einen Satz, unverändert vom globalen Ziel abgeleitet."
output_format: "return-Handover, maximal 150 Zeilen, Nachweise als Pfad"
tools_allowed:
  - "modules/tools.md#developer"
tools_forbidden:
  - "git push --force"
task_boundaries:
  - "Keine Schreibrechte ausser write_paths"
done_criteria:
  - "DoD des Knotens mit Exit 0 nachgewiesen"
start_point: "1. Leseliste 2. Befehl 3. erwartetes Ergebnis"
budget:
  files_read: 0
  bytes_read: 0
  tool_calls: 0
  turns: 0
reading_list:
  - AGENTS.md
artifacts: []
open_gates:
  - N4
dead_ends: []
created_at: "2026-08-07T00:00:00Z"
---

# Handover

## Auftrag
**Original-Prompt:** unverändert. **Out-of-scope / Grenzen:** siehe `task_boundaries`.
**Klasse / Flags / task_id:** Frontmatter. **DoD:** `done_criteria`, Nachweis mit Exit 0.

## Erkenntnisse
Artefakte nur als Pfad (`artifacts[]`). Sackgassen in `dead_ends[]`. Keine Logs inline.

## Startpunkt
Siehe `start_point`. Schreibzugriff nur laut Handover. Rückgabe an `parent_agent_id`,
`reason: return`, **dieselbe `task_id`**.
