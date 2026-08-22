---
handover_id: hv-a1b2
task_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
parent_agent_id: orc-7f3a
agent_id: dev-2b70
role: developer
depth: 1
node: N4
class: feature
flags:
  - sec
  - api
reason: delegation
goal: "OAuth2-Login mit Google als Provider im Zielprojekt ergaenzen."
output_format: "return-Handover, maximal 150 Zeilen; Kommandos mit Exit-Code"
tools_allowed:
  - "modules/tools.md#developer"
tools_forbidden:
  - "git push --force"
task_boundaries:
  - "Keine weiteren Provider"
  - "Passwort-Login nicht entfernen"
done_criteria:
  - "ruff check . endet mit Exit 0"
  - "pytest tests/auth/ endet mit Exit 0"
start_point: "Lies roles/developer.md und Zielprojekt-Docs; implementiere in src/auth/ und tests/auth/."
budget:
  files_read: 8
  bytes_read: 42000
  tool_calls: 12
  turns: 6
reading_list:
  - AGENTS.md
  - roles/developer.md
artifacts:
  - path: docs/requirements/oauth-google.md
    type: requirements
  - path: docs/adr/002-oauth-google.md
    type: adr
open_gates:
  - N4
  - N5a
  - dod:program_design
  - dod:human_plan_review
dead_ends: []
created_at: "2026-08-07T10:30:00Z"
---

# Handover-Beispiel (ausgefüllt)

Referenz zum Template `templates/handover.md`. Szenario: Orchestrator → Developer
(OAuth2 Google Login) in einem Zielprojekt.

## Auftrag
Google-OAuth ergänzen. Keine weiteren Provider, Passwort-Login bleibt.
Klasse `feature`, Flags `sec`+`api`, daher Plan und Plan-Review vor dem Bau.

## Erkenntnisse
Anforderungen und ADR liegen als Pfad in `artifacts[]`. Keine Sackgassen.

## Startpunkt
Siehe `start_point`. Schreiben nur unter `src/auth/` und `tests/auth/`.
Rückgabe an `orc-7f3a` mit derselben `task_id`.
