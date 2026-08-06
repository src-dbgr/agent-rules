# Abdeckung der Modell-Sonde (Modell ↔ Gesetz)

> Status: **beschränkte Modell-Sonde (bounded probe), keine Vollverifikation.** Nicht-normativ, nicht beim Bootstrap lesen.
> Normativ ist das strukturelle Rangargument in `modules/workflow.md#rank-funktion`. Diese Datei sagt, welchen Teil des
> Katalogs `runtime/architecture/cfg-v2-nodes.json` das Modell `specs/workflow.tla` prüft und welchen nicht; ein grüner
> Lauf belegt ausschließlich die unten aufgeführten Eigenschaften auf der unten aufgeführten Abstraktion.

## Ausgeführte Läufe (Stand 2026-08-05)

| Lauf | Kommando | Exit | Ergebnis |
|---|---|---:|---|
| Haupt | `java -cp lib/tla2tools.jar tlc2.TLC -config specs/workflow.cfg specs/workflow.tla` | 0 | 130.189 erzeugte, **46.101 verschiedene** Zustände, Suchtiefe 57, „No error has been found"; Zeile „Checking temporal properties for the complete state space with 46101 total distinct states" belegt, dass die temporale Eigenschaft geprüft wurde |
| Mutation | `java -cp lib/tla2tools.jar tlc2.TLC -config specs/mutation.cfg specs/workflow.tla` | **12** | `Error: Invariant InvGateOnly is violated.` — der Lauf **muss** scheitern |
| Kantenabdeckung | unabhängige Nachrechnung des Erreichbarkeitsgraphen (Python, gleiche Übergangsrelation) | 0 | 46.101 erreichbare Zustände (identisch zu TLC), **40 von 40** Katalogkanten werden von einer erreichbaren Transition benutzt |

## Geprüfte Eigenschaften und ihre Gegenprobe

Eine Invariante, die ihre eigenen Guards nachspricht, prüft nichts (Befund F-040). Deshalb wird jede Eigenschaft
**zusätzlich** gegen eine Mutante gehalten, die genau eine Schutzregel entfernt (alle in `specs/workflow.tla`).

| Eigenschaft | Aussage | Mutante, die sie bricht | Exit | Gegenprobe |
|---|---|---|---:|---|
| `TypeOK` | Zustandsraum und Zählerbereiche | `MutFixUnbounded` (Fix-Zähler ohne Schranke) | 12 | — |
| `InvAttempts` | Fix-Limit **je Rückkante** (N6b nur 1) | `MutDeliveryOverLimit` | 12 | derselbe Lauf hält `TypeOK` (Exit 0) → nicht aus `TypeOK` folgend |
| `InvOneShot` | höchstens eine One-shot-Eskalation je Art | `MutEscalateTwice` | 12 | derselbe Lauf hält `TypeOK` (Exit 0) |
| `InvGateOnly` | Aufenthalt nur an Pflichtknoten oder gesetzten Gates | `MutSkipGate` | 12 | — |
| `Termination` (temporal) | jeder faire Lauf erreicht einen Terminalzustand | `MutFixCounterReset` (Rückkanal setzt den Fix-Zähler zurück) | 13 | derselbe Lauf hält **alle vier** Invarianten (Exit 0) → die temporale Eigenschaft ist unabhängig |
| `CHECK_DEADLOCK` | kein Nicht-Terminalzustand ohne Nachfolger | Entfernen der Terminal-Selbstschleife | 11 | Prüfung ist wirksam, nicht deklarativ |
| Fairness-Bedarf | ohne `WF_vars(Next)` ist `Termination` verletzt | Spezifikation ohne Fairness-Annahme | 13 | „State 7: Stuttering" — die Annahme ist tragend, nicht kosmetisch |

**Grenze dieser Gegenproben:** Sie zeigen Verletzbarkeit, nicht Vollständigkeit. `CHECK_DEADLOCK` ist zusätzlich dadurch
entlastet, dass die Kante `* -> t_blocked` in jedem Knoten aktiviert ist: die Prüfung schließt Verklemmungen aus, belegt
aber keinen Vorwärtsfortschritt — der hängt an `Termination`.

## Knoten (13 von 13)

„abgedeckt" heißt: der Knoten ist ein erreichbarer Zustandswert. Es heißt **nicht**, dass DoD-Kriterien, Rolle oder
Nachweiskommando modelliert sind — das ist bei **keinem** Knoten der Fall (siehe „Nicht modelliert").

| Knoten | im Modell als | abgedeckt |
|---|---|---|
| `N0` | Startzustand | ja |
| `N1` | Pflichtknoten, Vorwärtskante | ja |
| `N2` | Pflichtknoten; Gate-Menge gilt danach als gegeben | ja |
| `N3a` | Gate im Profil | ja |
| `N3b` | Gate im Profil, zusätzlich Eskalationsziel | ja |
| `N3c` | Gate im Profil, zusätzlich Eskalationsziel | ja |
| `N4` | Gate im Profil, Ziel aller Rückkanten | ja |
| `N5a` | Gate im Profil, Quelle von Rückkante und Eskalation | ja |
| `N5b` | Gate im Profil, Quelle einer Rückkante | ja |
| `N5c` | Gate im Profil | ja |
| `N6a` | Gate im Profil, Quelle einer Rückkante | ja |
| `N6b` | Gate im Profil, Rückkante mit Limit 1 | ja |
| `N7` | Pflichtknoten vor dem Terminalzustand | ja |

## Kanten (40 von 40)

„abgedeckt" heißt: mindestens eine erreichbare Transition benutzt diese Kante. Die Bedingungstexte des Katalogs sind als
Auswahl über Gate-Profile abgebildet, nicht als Triage-Logik. Rohausgabe: `proof-artifacts/tlc_termination.log`.

| Kante | Modellaktion | abgedeckt |
|---|---|---|
| `N0 -> N1` | `Forward` | ja |
| `N1 -> N2` | `Forward` | ja |
| `N2 -> N3a` | `Forward` | ja |
| `N2 -> N3b` | `Forward` | ja |
| `N2 -> N3c` | `Forward` | ja |
| `N2 -> N4` | `Forward` | ja |
| `N2 -> N7` | `Forward` (leeres Gate-Profil) | ja |
| `N3a -> N3b` | `Forward` | ja |
| `N3a -> N3c` | `Forward` | ja |
| `N3a -> N4` | `Forward` | ja |
| `N3a -> N7` | `Forward` | ja |
| `N3b -> N3c` | `Forward` | ja |
| `N3b -> N4` | `Forward` | ja |
| `N3c -> N4` | `Forward` | ja |
| `N4 -> N5a` | `Forward` | ja |
| `N4 -> N6a` | `Forward` | ja |
| `N4 -> N6b` | `Forward` | ja |
| `N5a -> N5b` | `Forward`, `LoopPass` | ja |
| `N5a -> N5c` | `Forward`, `LoopPass` | ja |
| `N5a -> N6a` | `Forward`, `LoopPass` | ja |
| `N5a -> N6b` | `Forward`, `LoopPass` | ja |
| `N5b -> N5c` | `Forward`, `LoopPass` | ja |
| `N5b -> N6a` | `Forward`, `LoopPass` | ja |
| `N5b -> N6b` | `Forward`, `LoopPass` | ja |
| `N5c -> N6a` | `Forward` | ja |
| `N5c -> N6b` | `Forward` | ja |
| `N6a -> N6b` | `Forward`, `LoopPass` | ja |
| `N6a -> N7` | `Forward`, `LoopPass` | ja |
| `N6b -> N7` | `Forward`, `LoopPass` | ja |
| `N7 -> t_done` | `Terminate` | ja |
| `N7 -> t_blocked` | `Terminate`, `StopTheLine` | ja |
| `N7 -> t_abort` | `Terminate` | ja |
| `N5a -> N4` | `LoopFix` (Limit 3) | ja |
| `N5b -> N4` | `LoopFix` (Limit 3) | ja |
| `N6a -> N4` | `LoopFix` (Limit 3) | ja |
| `N6b -> N4` | `LoopFix` (Limit 1) | ja |
| `N5a -> N3b` | `Escalate` (One-shot) | ja |
| `N5a -> N3c` | `Escalate` (One-shot) | ja |
| `* -> *` | `Rotate` (Zähler, kein Identitätswechsel) | ja |
| `* -> t_blocked` | `StopTheLine`, `Exhausted` | ja |

## Nicht modelliert (ausdrücklich **nicht** nachgewiesen)

| Gegenstand | Warum nicht | Folge für die Aussagekraft |
|---|---|---|
| Triage: 6 Klassen, 9 Flags, Gate-Vereinigung | Gate-Menge wird initial als gegeben gewählt | Die Regelliste und die High-Water-Mark-Bildung sind ungeprüft; nur ihre **Ergebnisse** (11 Profile) treten auf |
| Agentenbaum: Tiefe, Fan-out, Rückgabe, Tiefe-4-Triade | keine Variable, kein Handover | Über Tiefenlimit und Spawn-Budget sagt der Lauf nichts |
| Rotation als Amtsübergabe, `orchestrator_lineage` | nur Zähler ohne Identität | Rotation ist als Terminierungsrisiko geprüft, als Verfahren nicht |
| Rollen, DoD-Inhalte, Nachweiskommandos je Knoten | nicht formalisierbar ohne Projektkontext | Ein Knoten „gilt" durch Erreichen, nicht durch Erfüllung |
| Memory, Artefakt-GC, VCS-Zustand, Auslieferungsergebnis, Zustandsschema, Phasenraum | eigene Zustandsräume ohne Terminierungsbezug | vollständig ungeprüft; Schemata prüft `ajv`, nicht TLC |
| Zahlen der Konfiguration (Rotations-Obergrenze u. a.) | Sondenschranken statt Config-Defaults (`MaxRotations = 2`) | Terminierung ist für die Sondenschranken geprüft; für beliebige endliche Schranken trägt allein `modules/workflow.md#rank-funktion` |

## Was daraus folgt — und was nicht

**Folgt:** Auf dieser Abstraktion gibt es keinen unendlichen fairen Lauf, keine Verklemmung, keine Überschreitung der
Rückkanal- und One-shot-Limits und keinen Aufenthalt außerhalb gesetzter Gates; der Normalfall „Fix → PASS → weiter" ist
erreichbar (`LoopPass`) — unter der Vorgängerfassung war er ausgeschlossen (F-041).
**Folgt nicht:** dass das Gesetzbuch terminiert — für die ausgelassenen Dimensionen trägt allein das strukturelle Argument; wer die Sonde als Beweis zitiert, zitiert sie falsch. **Offen (Backlog v2.1):** Triage, Agentenbaum, Amtsübergabe.
