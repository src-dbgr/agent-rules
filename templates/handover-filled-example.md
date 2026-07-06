---
handover_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
parent_agent_id: "00000000-0000-4000-8000-000000000001"
child_agent_id: "22222222-2222-4222-8222-222222222222"
handover_type: delegation
role_assigned: developer
cfg_node: 4
cfg_node_name: N4_implementation
tree_depth: 1
cycle_attempt: 1
context_utilization_percent: 28
token_budget_remaining: 180000
active_memory_count: 2
pending_memory_writes: 1
created_at: "2026-07-06T10:30:00Z"
schema_version: "1.3.1"
---

# Handover-Beispiel (ausgefüllt)

> Referenzimplementierung des Templates — nicht für Produktion kopieren.

## 1. Globales Ziel

**Original-Prompt:**
```
Füge OAuth2-Login mit Google als Provider hinzu
```

**Orchestrator-Interpretation:** Nutzer können sich mit Google OAuth2 anmelden; Session wird serverseitig verwaltet.

**Out-of-scope:**
- Weitere Provider (GitHub, Microsoft)
- Passwort-Login entfernen

**Track:** standard  
**Triage-Begründung:** Neue Auth-Integration, keine verteilte Kern-Concurrency → Standard-Track ausreichend.

## 2. Aktueller CFG-Knoten

| Feld | Wert |
|------|------|
| Knoten-ID | N4 |
| Knotenname | N4_implementation |
| Abgeschlossen | N0, N1, N2, N3b |
| Zyklus | none |
| Nächster bei Erfolg | N5_test_review |

**DoD:**
- [ ] `ruff check .` → Exit 0
- [ ] `pytest tests/auth/` → Exit 0

## 3. Erkenntnisse & Artefakte

| Artefakt | Pfad |
|----------|------|
| Akzeptanzkriterien | `docs/requirements/oauth-google.md` |
| ADR (light) | `docs/adr/002-oauth-google.md` |

```gherkin
Given ein Nutzer mit gültigem Google-Token
When er den Callback aufruft
Then wird eine Session erstellt und er ist eingeloggt
```

## 4. Sackgassen

Keine.

## 5. Startpunkt für Developer

1. Lese `docs/requirements/oauth-google.md`, `docs/adr/002-oauth-google.md`
2. Implementiere in `src/auth/google_oauth.py`
3. Tests in `tests/auth/test_google_oauth.py`
4. Run `pytest tests/auth/test_google_oauth.py -q`

**DoD dieser Übergabe:** pytest Exit 0, keine Secrets in Code.

## 6. Kontext-Budget

28 % — keine Rotation nötig.

## 7. Eltern

`parent_agent_id`: Orchestrator `00000000-0000-4000-8000-000000000001`

## 7a. Gedächtnis-Übergabe (Gesetz 9)

**Aktive Memories:**

| # | Layer | Scope | Inhalt | Quelle / trust | valid_until |
|---|-------|-------|--------|----------------|-------------|
| 1 | semantic | project | Akzeptanzkriterien OAuth-Google | `docs/requirements/oauth-google.md` / trusted | — |
| 2 | semantic | project | ADR-002: Google als erster Provider | `docs/adr/002-oauth-google.md` / trusted | — |

**Ausstehende Writes (Consolidation N7):**

| # | Layer | Scope | Kandidat | Screening |
|---|-------|-------|----------|-----------|
| 1 | episodic | project | „Session serverseitig, nicht im LocalStorage" (Begründung: XSS) | pending |

Kein Cross-Project-Leakage; keine Secrets/PII im Gedächtnis.
