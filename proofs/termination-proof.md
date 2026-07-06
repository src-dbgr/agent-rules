# Terminierungs- und Deadlock-Freiheitsbeweis (Erweiterung)

> **Version:** 1.1.0  
> **Bezug:** `workflow-cfg.md` §6–7, `specs/workflow.tla`, `memory-policy.md` §9 (Memory-Gates)

Dieses Dokument ergänzt den strukturellen Beweis in `workflow-cfg.md` um eine **formale TLA+-Skizze** und prüfbare Invarianten.

---

## 1. Modellierungsziel

Beweise für den abstrakten CFG:

1. **Termination:** `[]<>(phase \in {"done", "blocked"})` — stets erreicht ein Terminalzustand
2. **NoDeadlock:** Kein Zustand ohne Fortschritt außerhalb Terminal, der unbegrenzt persistiert
3. **BoundedCycles:** `cycle_attempt <= 3`
4. **BoundedDepth:** `tree_depth <= 4`

---

## 2. Zustandsvariablen (TLA+)

Siehe `specs/workflow.tla`:

- `phase` — Lebenszyklus
- `cfg_node` — aktueller Knoten 0..7
- `cycle` — 0..3
- `depth` — 0..4
- `in_loop` — Boolean
- `terminal` — Boolean

---

## 3. Invarianten (zu prüfen mit TLC)

| Invariante | Formel (informell) | Erzwingung |
|------------|-------------------|------------|
| **Inv_Cycle** | `cycle <= 3` | Orchestrator inkrementiert; bei 3 → Terminal |
| **Inv_Depth** | `depth <= 4` | Spawn-Guard auf Tiefe 4 |
| **Inv_Terminal** | `terminal => phase \in {done, blocked}` | Terminal-Definition |
| **Inv_Progress** | Hauptpfad erhöht `cfg_node` modulo begrenzter Rückkanäle | CFG-Struktur |

---

## 4. Rank-Funktion (Wiederholung)

Lexikographisches Tupel `R = ⟨terminal, −cfg_node_on_fail, cycle, depth⟩` mit endlichem Wertebereich.

**Hauptpfad:** `cfg_node` steigt → endlich viele Schritte bis `cfg_node = 7` → Terminal.

**Rückkanal:** `cfg_node` sinkt, aber `cycle` steigt (max 3) → dann Terminal-Transition.

**Spawn:** `depth` steigt (max 4) → dann keine weiteren Spawns.

⇒ **Keine unendliche Abstiegskette.**

---

## 5. Deadlock-Freiheit (Wartegraph)

Sei `W` der Wartegraph aktiver Agenten:

- Knoten: Agent-Instanzen
- Kante `A → B`: A wartet auf Handover/Return von B

**Lemma 1:** W ist ein Baum mit Wurzel Orchestrator (`depth=0`).

*Beweis:* Spawns nur von Eltern zu Kind; keine Peer-Kanten (AGENTS.md §4.2). ∎

**Lemma 2:** Maximale Tiefe von W ist 4.

*Beweis:* Gesetz 1, `max_depth = 4`. ∎

**Lemma 3:** Jede Rückkanal-Schleife (Developer↔Tester) hat höchstens 3 Iterationen.

*Beweis:* `cycles.max_attempts = 3`, erzwungen in State. ∎

**Theorem:** Kein permanenter Deadlock außerhalb Terminal.

*Skizze:* Ein permanenter Deadlock erfordert einen Zyklus in W oder unbegrenzte Rückkanal-Iteration. Lemma 1–3 schließen beides aus. Verbleibende Warte ist endlich (Kinder terminieren oder Hard Error). ∎

---

## 6. Ausführung des formalen Checks

```bash
# Voraussetzung: Java (JAVA_HOME), lib/tla2tools.jar (siehe scripts/verify-proofs.sh)
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home 2>/dev/null)}"
java -XX:+UseParallelGC -cp lib/tla2tools.jar tlc2.TLC -config specs/workflow.cfg specs/workflow.tla
```

Oder alle Bibel-Beweise gebündelt: `./scripts/verify-proofs.sh`

Erfolg: `Model checking completed. No error has been found.`

`specs/workflow.cfg` setzt `CHECK_DEADLOCK FALSE`, weil Terminalzustände (`terminal = TRUE`) keine weiteren Transitionen haben — das ist erwartetes Verhalten, kein CFG-Deadlock.

Ergebnis loggen nach `proof-artifacts/tlc_termination.log` und in `dod_gates.N3c_concurrent` eintragen.

---

## 7. Grenzen des Modells

Das TLA+-Modell abstrahiert:

- Kontext-Rotation (ersetzt Instanz, ändert `cfg_node` nicht)
- Parallele Sub-Agenten (modelliert als sequentiell aggregiert)
- **Memory-Operationen (Gesetz 9)** — Ingestion (N1) und Consolidation (N7) sind
  endliche Schleifen über eine endliche Menge Memory-Einträge; sie ändern
  `cfg_node`, `cycle` und `depth` **nicht** und führen keine neuen Kanten in den
  Wartegraphen ein. Sie sind daher im abstrakten Modell als knoten-lokale,
  atomare Aktionen innerhalb N1/N7 subsumiert.

Diese Abstraktionen **vergrößern** den Zustandsraum nicht unendlich und erhalten die Obergrenzen.

### 7.1 Memory-Operationen erhalten Termination & Deadlock-Freiheit

- **Termination:** Ingestion/Consolidation iterieren über
  `|memory.active| + |memory.pending_writes| < ∞`. Keine Aktion erhöht `cycle`
  oder `depth`, keine erzeugt einen Rückkanal. Die Rank-Funktion
  `R = ⟨terminal, −cfg_node_on_fail, cycle, depth⟩` bleibt unverändert monoton.
- **Deadlock-Freiheit:** Memory-Reads/Writes sind lokale Aktionen des Memory
  Curator (bzw. Orchestrators in dieser Funktion); sie erzeugen keine
  Peer-Wartekanten (AGENTS.md §4.2) und lassen den Wartegraphen `W` ein Baum
  mit Tiefe ≤ 4. Lemma 1–3 (§5) bleiben gültig. ∎

---

## 8. Literatur

- Lamport, L.: *Specifying Systems* — TLA+ Grundlagen
- LangGraph State-Machine-Pattern (bounded `max_steps`)
- TDAD (arXiv 2026): ausführbare Verhaltensnachweise statt Prosa-DoD
