---
handover_id: hv-a1b2
task_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
parent_agent_id: orc-7f3a
child_agent_id: "dev-2b70"
handover_type: delegation
role_assigned: developer
cfg_node: N4
tree_depth: 1
cycle_attempt: 1
files_read: 8
bytes_read: 42000
tool_calls: 12
turns: 6
created_at: "2026-08-07T10:30:00Z"
schema_version: "2.0.0"
---

# Handover-Beispiel (ausgefüllt)

> Referenz zum kanonischen Template `templates/handover.md` — nicht blind kopieren.
> Szenario: Orchestrator → Developer (OAuth2 Google Login) in einem **Zielprojekt**.

## 1. Globales Ziel

**Original-Prompt:**
```
Füge OAuth2-Login mit Google als Provider hinzu
```

**Out-of-scope:**
- Weitere Provider (GitHub, Microsoft)
- Passwort-Login entfernen

**Klasse / Flags:** `feature` + `[sec, api]`  
**task_id:** `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

## 2. CFG-Knoten

Knoten: `N4` | Vorher: `N3b` | Nächster bei Erfolg: `N5a`  
DoD:
- [ ] `ruff check .` → Exit 0
- [ ] `pytest tests/auth/` → Exit 0

## 3. Artefakte (Pfade, keine Volltexte)

| Artefakt | Pfad | Kurz |
|----------|------|------|
| Akzeptanzkriterien | `<zielprojekt>/docs/requirements/oauth-google.md` | Gherkin-Kriterien |
| ADR | `<zielprojekt>/docs/adr/002-oauth-google.md` | Google als erster Provider |

## 4. Schreibrechte (Parallelität)

`write_paths:` `<zielprojekt>/src/auth/`, `<zielprojekt>/tests/auth/` | disjunkt zu Geschwistern

## 5. Sackgassen

Keine.

## 6. Startpunkt (Empfänger)

Rolle: `developer`
1. Lies: `roles/developer.md`, Zielprojekt-Docs unter `<zielprojekt>/docs/`
2. Führe aus: Implementierung + Tests im Zielprojekt (`src/auth/`, `tests/auth/`)
3. Erwarte: `pytest tests/auth/ -q` Exit 0; keine Secrets im Code  
Schreibzugriff: Zielprojekt-Auth-Pfade | Nur lesen: Docs/ADR, `roles/developer.md` | Verboten: Vendor-Norm (`AGENTS.md`, `modules/`)

## 7. Rückgabe

An: `orc-7f3a` | Format: `handover_type: return` | Max. 150 Zeilen  
**Dieselbe `task_id` wiederholen** — sonst weist der Orchestrator ab.
