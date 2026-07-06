# Triage-Entscheidungsmatrix

> Version: 1.3.0
> Bezug: `workflow-cfg.md` §3, Node N2

Der Orchestrator bewertet die Nutzeranfrage anhand gewichteter Faktoren und
wählt **genau einen** Triage-Pfad. Bei Grenzfällen gilt: **flachster
ausreichender Pfad** (Anti-Overengineering) — Fast vor Standard vor Deep,
sofern alle Risiko-Signale abgedeckt sind.

---

## Entscheidungsbaum

```
START
 │
 ├─ Nur Text/Docs/Kommentare, kein Verhaltensrisiko?
 │   └─ JA → FAST_TRACK
 │
 ├─ Neue Nebenläufigkeit / verteilte Architektur / Auth / Payment / PII?
 │   └─ JA → DEEP_TRACK
 │
 ├─ Normales Feature / Bugfix mit fachlicher Logik?
 │   └─ JA → STANDARD_TRACK
 │
 └─ Unklar → STANDARD_TRACK (Default) + Researcher optional spawnen
```

---

## Scoring-Matrix (optional, für Grenzfälle)

Jeder Faktor: 0 (nein) oder 1 (ja). Summe `S`:

| Faktor | Fast | Standard | Deep |
|--------|------|----------|------|
| F1: Verhaltensänderung im Code | — | +1 | +1 |
| F2: Neue öffentliche API/Schnittstelle | — | +1 | +1 |
| F3: Datenbankschema-Änderung | — | +1 | +2 |
| F4: Auth/Security/PII | — | +1 | +2 |
| F5: Nebenläufigkeit/Verteilung | — | — | +2 |
| F6: Nur Text/Doku/Kommentar | −2 | — | — |
| F7: Bestehende Tests decken Änderung ab | −1 | — | — |

**Regel:**
- `S ≤ 0` → FAST_TRACK
- `1 ≤ S ≤ 3` → STANDARD_TRACK
- `S ≥ 4` → DEEP_TRACK

---

## Pfad → Rollen-Kette

| Pfad | Knotenfolge (Rollen) |
|------|----------------------|
| FAST_TRACK | Developer → Tester → Aggregation |
| STANDARD_TRACK | Business Analyst → Developer → Tester **(+ Architektur-Konformitäts-Gate)** → [UX/UI] → Documentation → Deploy Prep → Aggregation |
| DEEP_TRACK | Researcher → Business Analyst → Architect → Developer → [Security] → Tester **(+ Architektur-Konformitäts-Gate)** → [UX/UI] → Documentation → Deploy Prep → Aggregation |

`[UX/UI]` nur wenn visuelle/UI-Änderungen (Pflicht N9).
`[Security]` bei Angriffsflächen-Erweiterung oder Deep-Track-Default.
`(+ Architektur-Konformitäts-Gate)` = leichtgewichtige Drift-Erkennung durch den
Tester & Reviewer (Standard + Deep, Pflicht). Bei echtem Architekturbedarf:
Eskalation **N5 → N3c** (Hochstufung auf Deep, Architect spawnen, max 1×). Der
Fast-Track hat **kein** Gate (echte Trivialität verändert die Architektur nicht).

---

## Dokumentationspflicht

Nach Triage-Entscheidung in `.agent-state.json`:

```json
{
  "triage_path": "STANDARD_TRACK",
  "history": [{
    "event": "triage_decision",
    "details": "S=2: Feature mit fachlicher Logik, keine Nebenläufigkeit"
  }]
}
```

---

## Anti-Overengineering-Regeln

1. **Nicht** Deep-Track für Einzeiler oder reine Textfixes.
2. **Nicht** Fast-Track für Auth, Payment, Schema-Migrationen.
3. Researcher nur spawnen, wenn echte Wissenslücke besteht — nicht „auf Vorrat".
4. Architect-**Autorschaft** (ADR/Entwurf) nur im Deep-Track — Standard-Features
   brauchen keinen Vorab-Architekten und keinen ADR-Zwang. **Architektur-Drift**
   auf normalen Features wird stattdessen durch das leichtgewichtige
   **Architektur-Konformitäts-Gate** des Tester & Reviewers (N5, Standard + Deep)
   verhindert; erst wenn dieses Gate **echten** Architekturbedarf feststellt, wird
   per Eskalation **N5 → N3c** (max 1×) auf Deep hochgestuft und der Architect
   nachträglich gespawnt. So bleibt der Standard-Track schlank, ohne Drift zuzulassen.
