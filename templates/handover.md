---
handover_id: "<uuid>"
parent_agent_id: "<uuid>"
child_agent_id: "<uuid-or-empty>"
handover_type: delegation
role_assigned: developer
cfg_node: N4
tree_depth: 2
cycle_attempt: 1
files_read: 0
bytes_read: 0
tool_calls: 0
turns: 0
created_at: "2026-08-06T00:00:00Z"
schema_version: "2.0.0"
---

# Handover

## 1. Globales Ziel
**Original-Prompt:** `[unverändert]`
**Out-of-scope:** …
**Klasse / Flags:** `feature` + `[…]`

## 2. CFG-Knoten
Knoten: `N?` | Vorher: … | Nächster bei Erfolg: …
DoD: `- [ ] …` Nachweis: `` `befehl` `` → Exit 0

## 3. Artefakte (Pfade, keine Volltexte)
| Artefakt | Pfad | Kurz |
|----------|------|------|
| … | `…` | … |

## 4. Sackgassen
Keine | oder Tabelle Versuch / Warum verworfen / Log-Pfad

## 5. Startpunkt (Empfänger)
Rolle: …
1. Lies: `[pfade]`
2. Führe aus: `[befehl]`
3. Erwarte: `[ergebnis]`
Schreibzugriff: … | Nur lesen: … | Verboten: …

## 6. Rückgabe
An: `parent_agent_id` | Format: `handover_type: return` | Max. 150 Zeilen
