# Control-Flow-Graph (CFG) — Triage, Rollenpfade & Terminierungsbeweis

> **Version:** 1.1.0  
> **Status:** Verbindlich  
> **Bezug:** Gesetz 2 (CFG & Triage-Routing), Gesetz 6 (DoD & ausführbare Beweise), Gesetz 9 (Memory-Gates N1/N7)

Dieses Dokument definiert den **deterministischen Kontrollfluss** aller Agenten-Arbeitsabläufe. Der Orchestrator ist Eigentümer des Graphen; Sub-Agenten operieren innerhalb eines zugewiesenen Knotens und dürfen den globalen CFG **nicht** eigenmächtig überspringen.

---

## 1. Graph-Übersicht (ASCII)

```
                    ┌─────────────────────────────────────────────────────────┐
                    │  N0: INPUT — User Prompt (immer Start)                   │
                    └───────────────────────────┬─────────────────────────────┘
                                                │
                    ┌───────────────────────────▼─────────────────────────────┐
                    │  N1: BOOTSTRAP — Context Ingestion                       │
                    │  MUSS: agent-rules lesen + Prompt validieren              │
                    └───────────────────────────┬─────────────────────────────┘
                                                │
                    ┌───────────────────────────▼─────────────────────────────┐
                    │  N2: TRIAGE — Orchestrator wählt Track                    │
                    └───┬─────────────────┬─────────────────┬───────────────────┘
                        │                 │                 │
           ┌────────────▼──────┐ ┌────────▼────────┐ ┌──────▼──────────────┐
           │ FAST-TRACK        │ │ STANDARD-TRACK  │ │ DEEP-TRACK          │
           │ (trivial)         │ │ (normal)        │ │ (Architektur/Konk.) │
           └────────────┬──────┘ └────────┬────────┘ └──────┬──────────────┘
                        │                 │                 │
                        │         ┌───────▼───────┐  ┌──────▼───────┐
                        │         │ N3a: Research │  │ N3a: Research│
                        │         │ (optional)    │  │ (PFLICHT)    │
                        │         └───────┬───────┘  └──────┬───────┘
                        │                 │                 │
                        │         ┌───────▼───────┐  ┌──────▼───────┐
                        │         │ N3b: Business │  │ N3b: Business│
                        │         │ Analyst       │  │ Analyst      │
                        │         └───────┬───────┘  └──────┬───────┘
                        │                 │          ┌──────▼───────┐
                        │                 │          │ N3c: Architect│
                        │                 │          │ (PFLICHT)    │
                        │                 │          └──────┬───────┘
                        │                 │                 │
           ┌────────────▼─────────────────▼─────────────────▼──────────────┐
           │  N4: DEVELOPER — Implementierung                                 │
           └───────────────────────────┬─────────────────────────────────────┘
                                       │
           ┌───────────────────────────▼─────────────────────────────────────┐
           │  N5: TESTER & REVIEWER (+ UX/UI bei UI-Änderungen)                 │
           │  UI-Änderungen: PFLICHT visuelle Regressionstests                   │
           └───────────────┬───────────────────────────────┬───────────────────┘
                           │ PASS                          │ FAIL (Zyklus ≤3)
                           │                               └──────┐
                           │                                      │
                           │         ┌────────────────────────────▼────────┐
                           │         │ N4 ← Rückkanal (max 3 Versuche)       │
                           │         └───────────────────────────────────────┘
                           │
           ┌───────────────▼───────────────────────────────────────────────────┐
           │  N6: SECURITY AUDITOR (Standard/Deep; Fast nur bei Security-Signal) │
           └───────────────┬───────────────────────────────────────────────────┘
                           │
           ┌───────────────▼───────────────────────────────────────────────────┐
           │  N7: AGGREGATION — Orchestrator konsolidiert & antwortet Nutzer      │
           └───────────────┬───────────────────────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │ TERMINAL: SUCCESS (done) │  oder  TERMINAL: BLOCKED / ABORT
              └─────────────────────────┘
```

---

## 2. Knotendefinitionen & DoD-Gates

Jeder Knotenwechsel erfordert **ausführbare Nachweise** (Gesetz 6). Prosa allein reicht nicht.

| Knoten | Name | Verantwortlich | DoD (hart, nachweisbar) |
|--------|------|----------------|-------------------------|
| **N0** | Input | — | `original_user_prompt` in `.agent-state.json` gesetzt |
| **N1** | Bootstrap (+ Memory Ingestion) | Orchestrator / Memory Curator | Checkliste: `AGENTS.md`, `workflow-cfg.md`, `tools-registry.md`, `handover-template.md`, `memory-policy.md` gelesen; **Memory Ingestion** (semantic/procedural/episodic geladen, Provenienz/TTL/Poisoning geprüft, `memory.active[]` gesetzt); State initialisiert; Prompt als umsetzbar/unklar/verboten klassifiziert |
| **N2** | Triage | Orchestrator | `triage.decision` ∈ {fast, standard, deep}; `rationale` + `complexity_score` dokumentiert; Anti-Overengineering: tiefster ausreichender Track |
| **N3a** | Research | Researcher | Quellen mit URLs/Referenzen; Unsicherheiten markiert; nur Standard/Deep (Fast: übersprungen) |
| **N3b** | Business Analysis | Business Analyst | Akzeptanzkriterien (Given/When/Then); keine offenen Widersprüche ohne dokumentierte Annahme |
| **N3c** | Architecture | Architect | ADR(s); Schnittstellen; **nur Deep-Track**; TLA+ nur bei kritischen Nebenläufigkeits-Kernsystemen (siehe §4) |
| **N4** | Implementation | Developer | Build/Lint grün; keine Secrets; Schnittstellenkonformität |
| **N5** | Test & Review | Tester & Reviewer | **Alle** Akzeptanzkriterien getestet; `pytest`/`npm test`/etc. Exit 0; UI: visuelle Regression Exit 0 |
| **N6** | Security | Security Auditor | SAST/SCA Exit 0 oder dokumentierte Akzeptanz; keine kritischen Findings offen |
| **N7** | Aggregation (+ Memory Consolidation) | Orchestrator / Memory Curator | Teilergebnisse konsolidiert; **Memory Consolidation** (durable Learnings geschrieben, Stale expiriert/superseded, Secret/PII- + Injection-Scan bestanden, Scope korrekt, Snapshot abgelegt); `phase: done` oder `blocked` |

### 2.1 Nachweis-Typen je Knoten

```json
{
  "N4": { "proof_type": "unit_test", "proof_command": "pytest -q", "proof_exit_code": 0 },
  "N5": { "proof_type": "integration_test", "proof_command": "npm run test:e2e", "proof_exit_code": 0 },
  "N5_ui": { "proof_type": "visual_regression", "proof_command": "npx playwright test --grep @visual", "proof_exit_code": 0 },
  "N3c_concurrent": { "proof_type": "tla_verify", "proof_command": "java -cp tla2tools.jar tlc2.TLC -config workflow.cfg specs/workflow.tla", "proof_exit_code": 0 },
  "N1_memory_ingest": { "proof_type": "memory_scan", "proof_command": "gitleaks detect --source runtime/handovers --no-git && npx ajv-cli validate -s schemas/agent-state.schema.json -d .agent-state.json", "proof_exit_code": 0 },
  "N7_memory_consolidate": { "proof_type": "memory_scan", "proof_command": "gitleaks detect --source runtime/handovers --no-git", "proof_exit_code": 0 }
}
```

Einträge in `.agent-state.json` → `dod_gates`. Die Memory-Gates (N1/N7) sind in
`memory-policy.md` §9–10 detailliert; sie erzwingen Gesetz 9 (Ingestion &
Consolidation) mit ausführbaren Nachweisen statt Prosa.

---

## 3. Triage-Routing (Anti-Overengineering)

Der Orchestrator wählt auf **N2** genau einen Track. Default bei Unsicherheit: **Standard-Track** (nicht Deep).

### 3.1 Fast-Track

**Wann:** Triviale Änderungen — Tippfehler, Kommentare, reine Dokumentation ohne Verhaltensänderung, Konfigurationswerte ohne Sicherheitsimpact, einzeilige Bugfixes mit bestehender Testabdeckung.

**Pfad:** N0 → N1 → N2 → **N4 Developer** → **N5 Tester** → N7

**Übersprungen:** Research, Business Analyst (ersetzt durch Mini-Akzeptanzkriterium im Handover), Architect, Security (außer `signals` enthält `security_surface`).

**Komplexitäts-Score:** 1–3

### 3.2 Standard-Track

**Wann:** Normale Features, API-Erweiterungen, Refactorings mit Tests, mittlere Komplexität ohne verteilte Nebenläufigkeit im Kern.

**Pfad:** N0 → N1 → N2 → N3b Business Analyst → N4 → N5 → N6 (wenn Security-Signal) → N7

**Research (N3a):** Optional, wenn externe Standards/CVEs relevant.

**Komplexitäts-Score:** 4–7

### 3.3 Deep-Track

**Wann:** Kernarchitektur, verteilte Systeme, **Nebenläufigkeit/Race Conditions**, neue Persistenzschichten, sicherheitskritische AuthZ/AuthN-Kernpfade, Multi-Service-Orchestrierung.

**Pfad:** N0 → N1 → N2 → N3a Research → N3b Business Analyst → N3c Architect → N4 → N5 → N6 → N7

**Research & Architect:** Pflicht.

**Komplexitäts-Score:** 8–10

### 3.2 Triage-Entscheidungsmatrix

| Signal | Fast | Standard | Deep |
|--------|------|----------|------|
| Nur Text/Docs | ✓ | | |
| Neue Business-Logik | | ✓ | |
| UI-Änderung | | ✓ | |
| Neue API / Schema | | ✓ | |
| Concurrency im Kern | | | ✓ |
| Security-kritischer Pfad | | ✓ (min.) | ✓ |
| Architektur-Neuausrichtung | | | ✓ |

**Regel:** Wähle den **flachsten** Track, der alle Signale abdeckt. Begründe Abweichung nach oben in `triage.rationale`.

---

## 4. Architektur & formale Verifikation (Deep-Track)

**Grundsatz:** Testgetriebene Architektur ist der Default. TLA+, Petri-Netze oder äquivalente formale Methoden sind **nur** Pflicht, wenn **alle** Bedingungen erfüllt:

1. Deep-Track aktiv
2. Änderung betrifft **kritisches nebenläufiges Kernsystem** (z. B. verteilter Lock, Leader Election, Transaktionskoordinator)
3. Fehlerklasse wäre nicht durch Unit/Integration-Tests allein mit hoher Confidence abdeckbar

**Bei TLA+:** Generierung von `.tla`-Dateien allein genügt **nicht**. `dod_gates` muss `tlc`-Exit-Code 0 dokumentieren (siehe `tools-registry.md`, `specs/workflow.tla`).

**Sonst:** Clean Architecture, Interface Contracts, Property-Based Tests, Chaos-Tests wo sinnvoll.

---

## 5. Begrenzte Zyklen (Bounded Loops)

### 5.1 Erlaubte Rückkanäle

| Von | Nach | Auslöser | Limit |
|-----|------|----------|-------|
| N5 | N4 | Test/Review-Fehler | max 3 |
| N6 | N4 | Security-Finding (fixbar) | max 3 |
| N5 | N3b | Anforderungslücke entdeckt | max 1 (sonst Eskalation) |
| beliebig | Handover | Kontext ≥ 80 % | unbegrenzt (Rotation, kein Fix-Zyklus) |

### 5.2 Zähler-Semantik

- `cycles.current_attempt` startet bei 1 bei Eintritt in einen Rückkanal
- Bei jedem FAIL: inkrementieren
- Bei Erreichen von 3: **Zwangsterminierung** — einer von:
  - **Fallback:** Orchestrator liefert best-effort mit dokumentierten Limitationen (`phase: done` + `blockers`)
  - **Abort:** `phase: blocked`, Nutzer informiert
  - **Flag:** Orchestrator entscheidet manuelle Intervention / Track-Wechsel (z. B. Fast → Standard)

**Kein stiller vierter Versuch.**

---

## 6. Terminierungsbeweis (strukturell)

Wir beweisen: **Jede Ausführung terminiert in endlicher Zeit** in einem Terminalzustand `{SUCCESS, BLOCKED, ABORT}`.

### 6.1 Zustandsraum

Sei der abstrakte Zustand:

```
S = (node, track, depth, cycle, phase)
```

mit:

- `node ∈ {N0,…,N7} ∪ Terminal`
- `track ∈ {fast, standard, deep}`
- `depth ∈ {0,1,2,3,4}` (harte Obergrenze)
- `cycle ∈ {1,2,3}` wenn in Rückkanal, sonst `cycle = 0`
- `phase` aus Schema-Enum

### 6.2 Rank-Funktion (Lyapunov-artig)

Definiere Rang `R(S)` als lexikographisches Tupel:

```
R(S) = (is_terminal, forward_progress, −cycle, −depth)
```

wobei:

- `is_terminal ∈ {0,1}` — 1 iff `node ∈ Terminal`
- `forward_progress` — monotone Ordnung der Hauptpfad-Knoten (N0 < N1 < … < N7 < Terminal)
- `cycle` — bei Rückkanal erhöht sich `cycle`; bei Fortschritt auf Hauptpfad wird `cycle` auf 0 zurückgesetzt
- `depth` — Sub-Agenten-Spawns erhöhen `depth` bis max 4, dann **kein weiterer Spawn** (Gesetz 1)

### 6.3 Transitionen und Monotonie

**Hauptpfad-Transitionen (N0→N1→…→N7→Terminal):**  
`forward_progress` strikt steigend; `cycle = 0`. ⇒ `R` strikt abnehmend in der lex-Ordnung bis Terminal.

**Rückkanal-Transitionen (N5→N4, N6→N4):**  
`forward_progress` temporär rückläufig, aber `cycle` strikt steigend mit Obergrenze 3. Nach 3 Versuchen: Transition zu Terminal(BLOCKED|ABORT|FALLBACK) — **kein** weiterer Rückkanal.

**Spawn-Transitionen:**  
`depth` steigt maximal bis 4. Auf `depth = 4`: Spawn verboten; nur Solution | Abstract | Hard Error (endliche Aktion).

**Handover-Rotation:**  
Ersetzt Agent-Instanz ohne Zyklus-Inkrement; `node` unverändert; Kontext zurückgesetzt — endliche Operation.

### 6.4 Schlusssatz

1. Die Menge der möglichen `node`-Werte ist **endlich**.
2. `cycle ≤ 3` ist **invariant** (erzwungen durch Orchestrator).
3. `depth ≤ 4` ist **invariant** (Gesetz 1).
4. Rückkanäle können `forward_progress` höchstens **endlich oft** reduzieren (3× pro aktivem Loop-Typ, endlich viele Loop-Typen).
5. Hauptpfad hat endliche Länge ≤ 8 Knoten.

⇒ Es existiert keine unendliche gültige Transitionenfolge. **Jede Ausführung terminiert.**

### 6.5 Memory-Gates erhalten die Terminierung

Die Memory-Operationen an N1 (Ingestion) und N7 (Consolidation, Gesetz 9) sind
**endliche, begrenzte** Aktionen: Sie iterieren über die **endliche** Menge
aktiver bzw. ausstehender Memory-Einträge (`memory.active[]`,
`memory.pending_writes[]`), erzeugen **keine** neuen CFG-Zyklen, treten in keinen
Rückkanal ein und erhöhen weder `cycle` noch `depth`. In der Rank-Funktion `R(S)`
verändern sie ausschließlich knoten-lokalen Zustand innerhalb N1 bzw. N7, ohne
`forward_progress` rückläufig zu machen. Damit bleibt die Rank-Funktion strikt
monoton fallend und der Terminierungsbeweis **unverändert gültig**.

Siehe auch `proofs/termination-proof.md` für TLA+-Modell.

---

## 7. Deadlock-Freiheitsbeweis

**Deadlock** (in diesem CFG): Zustand, in dem kein Agent Fortschritt machen kann, kein Terminal erreicht wird, und keine gültige Transition existiert.

### 7.1 Wartegraph

Knoten = aktive Agenten; Kante A→B iff B wartet auf Ergebnis/Handover von A.

### 7.2 Eigenschaften

1. **Baumtopologie:** Eltern wartet auf Kinder; Kinder melden zurück. Keine zyklischen Wartekanten zwischen Geschwistern ohne Eltern (verboten, `AGENTS.md` §4.2).
2. **Orchestrator als Wurzel:** Jeder Pfad endet in Orchestrator (Tiefe 0). Maximale Pfadlänge ≤ 4.
3. **Timeout durch Zykluslimit:** Rückkanal-Schleifen Developer↔Tester terminieren spätestens nach 3 Iterationen.
4. **Kein gegenseitiges Warten:** Sub-Agenten kommunizieren nur über Eltern (kein Peer-Handover).

### 7.3 Schlusssatz

Der Wartegraph ist ein **DAG mit maximaler Tiefe 4** plus endlich begrenzte Rückkanal-Kanten, die nach 3 Durchläufen in Terminal überführt werden. Ein Zyklus im Wartegraph würde eine unendliche Spawn- oder Wartekette erfordern — durch `max_depth=4` und `max_attempts=3` ausgeschlossen.

**⇒ Der CFG ist deadlock-frei.**

---

## 8. Orchestrator-Pflichten pro Knoten

| Aktion | Pflicht |
|--------|---------|
| Knoten betreten | `cfg.active_node` aktualisieren; Sub-Agent spawnen mit Handover |
| Sub-Agent läuft | `running_sub_agents[].status = running` |
| DoD erfüllt | `dod_gates` mit `proof_exit_code`; `completed_nodes` erweitern |
| Zyklus FAIL | `cycles.current_attempt++`; bei 3 → Terminal-Policy |
| Kontext ≥ 80 % | Handover-Rotation; `phase: handover_pending` |

---

## 9. Knoten-Mapping (Kern ↔ Erweitert)

`AGENTS.md` §6 nutzt erweiterte Knotennummern für optionale Rollen. Mapping:

| Kern (`workflow-cfg.md`) | Erweitert (`AGENTS.md`) | Rolle |
|--------------------------|-------------------------|-------|
| N0 | N0 | Input |
| N1 | N1 | Bootstrap |
| N2 | N2 | Triage |
| N3a | N3 | Researcher |
| N3b | N4 | Business Analyst |
| N3c | N5 | Architect |
| N4 | N6 | Developer |
| N5 | N8 (+ N9 UX/UI bei UI) | Tester & Reviewer |
| N6 | N7 | Security Auditor |
| N7 | N12 | Aggregation |
| — | N10 | Documentation (Standard/Deep optional) |
| — | N11 | DevOps/SRE (deploy-relevant) |

---

## 10. Verweise

- Rollen: `AGENTS.md`
- State: `schemas/agent-state.schema.json`
- Handover: `handover-template.md`
- Werkzeuge: `tools-registry.md`
- Gedächtnis (Gesetz 9): `memory-policy.md`
- TLA+ Referenz: `specs/workflow.tla`
- Erweiterter Beweis: `proofs/termination-proof.md`
