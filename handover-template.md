# Handover-Protokoll — Hochleistungs-Kontextübergabe

> **Version:** 1.2.0  
> **Status:** Verbindlich (Gesetz 5 & Gesetz 9)  
> **Zweck:** Strukturierte Übergabe zwischen Agenten ohne Kontext-Überlauf, ohne implizite Annahmen und mit expliziter Gedächtnis-Übergabe

Jeder Übergang — Delegation nach unten, Rückgabe nach oben, Eskalation, Kontext-Rotation — **muss** diesem Template folgen. Freitext ohne Pflichtfelder ist **ungültig**.

**Speicherort im Zielprojekt:** `runtime/handover-<uuid>.md` (nicht ins Gesetzbuch committen)

---

## Metadaten (YAML-Frontmatter, maschinenlesbar)

```yaml
---
handover_id: "<uuid>"
parent_agent_id: "<uuid>"
child_agent_id: "<uuid>"          # leer bei Rückgabe an Eltern
handover_type: delegation       # delegation | return | escalation | context_rotation
role_assigned: developer        # siehe AGENTS.md §3
cfg_node: 4
cfg_node_name: N4_implementation
tree_depth: 2                   # 1-4 für Sub-Agenten; 0 = Orchestrator
cycle_attempt: 1                # 1-3 wenn in Rückkanal; sonst 1
context_utilization_percent: 45
token_budget_remaining: 120000
active_memory_count: 3            # Anzahl aktiver Memory-Einträge (Gesetz 9)
pending_memory_writes: 1         # ausstehende Consolidation-Kandidaten
created_at: "2026-07-06T10:00:00Z"
schema_version: "1.2.0"
---
```

---

## 1. Globales Ziel (unveränderlich seit N0)

> **Pflicht:** Wörtliche oder präzise paraphrasierte Wiedergabe von `original_user_prompt` aus `.agent-state.json`. Keine Scope-Erweiterung ohne Orchestrator-Freigabe.

**Original-Prompt:**
```
[Hier den vollständigen Nutzer-Prompt einfügen]
```

**Orchestrator-Interpretation (1–3 Sätze):**
[Was soll am Ende für den Nutzer wahr sein?]

**Explizit out-of-scope:**
- [Punkt 1]
- [Punkt 2]

**Track:** fast | standard | deep  
**Triage-Begründung (Kurz):** [Warum dieser Track]

---

## 2. Aktueller CFG-Knoten

| Feld | Wert |
|------|------|
| Knoten-ID | N?_... |
| Knotenname | [z. B. N4_implementation] |
| Vorherige abgeschlossene Knoten | [N0, N1, N2, …] |
| Aktiver Zyklus | none \| test_fix \| review_fix \| security_fix |
| Versuch | X von 3 |
| Nächster erwarteter Knoten nach Erfolg | [z. B. N5_test_review] |

**DoD dieses Knotens (Checkliste):**
- [ ] Kriterium 1 — Nachweis: `[Befehl]` → Exit `0`
- [ ] Kriterium 2 — …

---

## 3. Erkenntnisse & Code-Artefakte

### 3.1 Fachliche / technische Erkenntnisse

| # | Erkenntnis | Quelle / Evidenz | Vertrauen |
|---|------------|------------------|-----------|
| 1 | … | URL, Datei, Test | hoch/mittel/niedrig |

### 3.2 Artefakt-Register (Pfade, keine Volltexte)

| Artefakt | Pfad | Typ | Kurzbeschreibung |
|----------|------|-----|------------------|
| ADR-001 | `docs/adr/001-auth.md` | adr | OAuth2-Flow |
| Implementierung | `src/auth/oauth.py` | code | … |
| Tests | `tests/test_oauth.py` | test | 12 Fälle, alle grün |

### 3.3 Akzeptanzkriterien (falls von Business Analyst)

```gherkin
Given ein registrierter Nutzer
When er sich mit gültigem OAuth2-Token anmeldet
Then erhält er eine Session mit TTL 24h
```

### 3.4 Architekturvorgaben (falls Architect)

- Komponenten: [Liste]
- Schnittstellen: [Signaturen / OpenAPI-Ref]
- ADR-Links: [Pfade]
- Formale Spec (nur Deep+Concurrent): [TLA+ Pfad + `tlc` Ergebnis]

---

## 4. Sackgassen & Fehlerlogs (Dead Ends)

> **Pflicht auch bei Erfolg:** "Keine" explizit schreiben, wenn zutreffend.

### 4.1 Verworfene Ansätze

| Versuch | Ansatz | Warum verworfen | Log-/Pfad-Referenz |
|---------|--------|-----------------|---------------------|
| 1 | JWT im LocalStorage | XSS-Risiko | `runtime/logs/attempt-1.txt` |

### 4.2 Fehler & Blocker

```
[Relevante stderr/stdout-Auszüge oder Pfad zu Logdatei]
```

### 4.3 Offene Fragen an Orchestrator / Nutzer

- [ ] Frage 1 (blockierend: ja/nein)

---

## 5. Exakter Startpunkt für den empfangenden Agenten

> **Pflicht:** Der neue Agent muss **ohne Rückfragen** hier beginnen können.

**Rolle des Empfängers:** [z. B. Tester & Reviewer]

**Erste Aktion (imperativ):**
1. Lese Datei(en): `[Pfadliste]`
2. Führe aus: `[exakter Befehl]`
3. Erwarte: `[konkretes Ergebnis]`
4. Bei Abweichung: [Eskalation | Rückkanal N4 | Hard Error]

**Dateien mit Schreibzugriff:** [Liste]  
**Dateien nur lesen:** [Liste]  
**Verbotene Aktionen:** [z. B. kein git push, keine Schema-Migration]

**Definition of Done für diese Übergabe:**
- [ ] Messbares Kriterium 1
- [ ] Messbares Kriterium 2

**Geschätzter Kontextbedarf:** niedrig | mittel | hoch

---

## 6. Kontext-Budget & Rotations-Trigger

| Metrik | Wert | Schwelle | Aktion |
|--------|------|----------|--------|
| `context_utilization_percent` | __% | 80 % | Handover-Rotation vorbereiten |
| `token_budget_remaining` | __ | — | — |

**Bei ≥ 80 %:** Empfänger MUSS nach Abschluss der ersten atomaren Teilaufgabe `handover_type: context_rotation` an gleiche Rolle spawnen.

---

## 7. Eltern-Agent & Rückkanal

| Feld | Wert |
|------|------|
| `parent_agent_id` | [uuid] |
| Rückgabeformat | Handover `handover_type: return` |
| Bei Hard Error | Abschnitt 4 vollständig + `severity: critical` in State |

---

## 7a. Gedächtnis-Übergabe (Gesetz 9 / `memory-policy.md`)

> **Pflicht, wenn persistentes Gedächtnis relevant ist** (Fortsetzung, RAG/Memory-Store,
> projektübergreifende Konventionen). Sonst „Kein persistentes Gedächtnis relevant"
> explizit vermerken. Freitext-Referenz, keine Volltexte/Secrets.

### 7a.1 Aktive Memories (dem Empfänger übergeben)

| # | Layer | Scope | Inhalt (kurz) | Quelle / `trust` | `valid_until` |
|---|-------|-------|---------------|------------------|---------------|
| 1 | semantic | project | Projekt nutzt CSS-Variablen fürs Theming | `src/styles/theme.css` / trusted | — |
| 2 | episodic | project | Ansatz „JWT im LocalStorage" verworfen (XSS) | HO-…/attempt-1 / trusted | — |

### 7a.2 Ausstehende Writes (Consolidation-Kandidaten für N7)

| # | Layer | Scope | Kandidat | Poisoning/PII-Screening |
|---|-------|-------|----------|-------------------------|
| 1 | semantic | project | „Playwright-Baseline in tests/visual/" | `pending` (bei N7 prüfen) |

### 7a.3 Memory-Regeln für den Empfänger

- **Kein** Cross-Project-Leakage (Gesetz 9.2): `project`-Wissen nicht nach `user`/`global`.
- Abgelaufene/`superseded` Einträge revalidieren, nicht blind nutzen (Gesetz 9.3).
- Untrusted/unverified Einträge nicht ohne Verifikation nach semantic/procedural (Gesetz 9.4).
- Keine Secrets/PII persistieren (Gesetz 9.5).

---

## 8. Validierung vor Senden (Checkliste)

Sender (meist Eltern-Agent oder Orchestrator) bestätigt:

- [ ] Abschnitt 1 entspricht `original_user_prompt` (kein Scope-Creep)
- [ ] Abschnitt 2 stimmt mit `.agent-state.json` → `cfg` überein
- [ ] Abschnitt 3 referenziert Pfade, keine 500+ Zeilen Inline-Code
- [ ] Abschnitt 4 ist ausgefüllt (oder "Keine")
- [ ] Abschnitt 5 ist **ausführbar** ohne zusätzlichen Kontext
- [ ] Abschnitt 7a: aktive Memories + ausstehende Writes gelistet (oder "nicht relevant"); Scope/`trust`/TTL gesetzt; keine Secrets/PII
- [ ] Frontmatter vollständig und gültig (inkl. `active_memory_count`, `pending_memory_writes`)
- [ ] `tree_depth` ≤ 4; bei 4 kein weiterer Spawn geplant

---

## Anhang: Minimal-Handover (Fast-Track)

Für Fast-Track dürfen Abschnitte 3.3–3.4 entfallen, wenn im Handover mindestens steht:

```markdown
## Mini-Akzeptanz
- [ ] Änderung X bewirkt Y (prüfbar via `command`)

## Startpunkt
1. Edit `path/to/file`
2. Run `pytest tests/test_x.py`
```

Alle anderen Pflichtabschnitte (1, 2, 4, 5, Frontmatter) bleiben **verbindlich**.
