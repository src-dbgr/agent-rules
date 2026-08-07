---
handover_id: "<uuid>"
task_id: "<uuid>"
parent_agent_id: "<id>"
child_agent_id: "<id-or-empty>"
handover_type: delegation
role_assigned: developer
cfg_node: N4
tree_depth: 2
cycle_attempt: 1
files_read: 0
bytes_read: 0
tool_calls: 0
turns: 0
created_at: "2026-08-07T00:00:00Z"
schema_version: "2.0.0"
---

# Handover

## 1. Globales Ziel
**Original-Prompt:** `[unverändert]`
**Out-of-scope:** …
**Klasse / Flags:** `feature` + `[…]`
**task_id:** `[UUID — Pflicht, Korrelation zum Assignment-Ledger]`

## 2. CFG-Knoten
Knoten: `N?` | Vorher: … | Nächster bei Erfolg: …
DoD: `- [ ] …` Nachweis: `` `befehl` `` → Exit 0

## 3. Artefakte (Pfade, keine Volltexte)
| Artefakt | Pfad | Kurz |
|----------|------|------|
| … | `…` | … |

## 4. Schreibrechte (Parallelität)
`write_paths:` … (disjunkt zu Geschwistern) | sonst: Eskalation

## 5. Sackgassen
Keine | oder Tabelle Versuch / Warum verworfen / Log-Pfad

## 6. Startpunkt (Empfänger)
Rolle: …
1. Lies: `[pfade]`
2. Führe aus: `[befehl]`
3. Erwarte: `[ergebnis]`
Schreibzugriff: … | Nur lesen: … | Verboten: …

## 7. Rückgabe
An: `parent_agent_id` | Format: `handover_type: return` | Max. 150 Zeilen
**Dieselbe `task_id` wiederholen** — sonst weist der Orchestrator ab.
