---- MODULE workflow ----
(*
  BESCHRAENKTE MODELL-SONDE (bounded probe) des CFG v2 — kein Vollbeweis.

  Normativ ist das strukturelle Rangargument in modules/workflow.md (Abschnitt
  rank-funktion). Diese Datei prueft eine Abstraktion davon maschinell. Was sie
  abdeckt und was nicht, steht vollstaendig und pro Knoten/Kante in
  specs/coverage.md. Wer aus einem gruenen Lauf dieser Datei auf die
  Korrektheit des Gesetzbuchs schliesst, ueberdehnt den Nachweis.

  Hauptlauf:      java -cp lib/tla2tools.jar tlc2.TLC -config specs/workflow.cfg specs/workflow.tla
  Mutationslauf:  java -cp lib/tla2tools.jar tlc2.TLC -config specs/mutation.cfg specs/workflow.tla
  Der Mutationslauf MUSS mit Exit != 0 enden; sonst pruefen die Invarianten nichts.
  Beides fuehrt scripts/verify-proofs.sh aus.

  Abstraktionen (bewusst, nachlesbar in specs/coverage.md):
   - Die Gate-Menge (Ergebnis der Triage) wird nichtdeterministisch initial
     gewaehlt; die Triage-Regeln selbst sind nicht modelliert.
   - Agentenbaum, Rollen, Handover, Memory, Artefakt-GC und VCS-Zustand fehlen.
   - Rotation ist eine Selbstkante mit Zaehler, ohne Identitaetswechsel.
*)

EXTENDS Naturals, FiniteSets

CONSTANTS MaxCounter,     \* Typschranke der Zaehler (weiter als die Rechtsgrenzen)
          MaxOneShot,     \* Rechtsgrenze der One-shot-Eskalationen
          MaxRotations    \* Modellschranke der Rotationen (Sondenwert, nicht der Config-Default)

ASSUME MaxCounter \in Nat /\ MaxCounter >= 3
ASSUME MaxOneShot = 1
ASSUME MaxRotations \in Nat

\* ---------------------------------------------------------------- Knotenraum
MandatoryNodes == {"N0", "N1", "N2", "N7"}
GatedNodes     == {"N3a", "N3b", "N3c", "N4", "N5a", "N5b", "N5c", "N6a", "N6b"}
NodeIds        == MandatoryNodes \cup GatedNodes
TerminalIds    == {"t_done", "t_blocked", "t_abort"}

\* Lexikographische Ordnung auf (rank, letter) des Katalogs, flach numeriert.
Order == [ N0  |-> 0, N1  |-> 1, N2  |-> 2,
           N3a |-> 3, N3b |-> 4, N3c |-> 5,
           N4  |-> 6,
           N5a |-> 7, N5b |-> 8, N5c |-> 9,
           N6a |-> 10, N6b |-> 11,
           N7  |-> 12 ]

\* Rueckkanten und ihre Limits (Katalog: 3/3/3/1). Zaehler sind kumulativ.
BackEdges    == {"n5a_n4", "n5b_n4", "n6a_n4", "n6b_n4"}
AttemptLimit == [ n5a_n4 |-> 3, n5b_n4 |-> 3, n6a_n4 |-> 3, n6b_n4 |-> 1 ]
BackFrom     == [ N5a |-> "n5a_n4", N5b |-> "n5b_n4", N6a |-> "n6a_n4", N6b |-> "n6b_n4" ]
RetryNodes   == DOMAIN BackFrom

\* One-shot-Eskalationen von N5a.
OneShots      == {"requirements_gap", "architecture_drift"}
OneShotTarget == [ requirements_gap |-> "N3b", architecture_drift |-> "N3c" ]

(* Gate-Profile: Ergebnis der Triage, hier als gegeben angenommen. Die Auswahl
   ist so gewaehlt, dass jede Vorwaertskante des Katalogs in mindestens einem
   Profil erreichbar ist (Nachweis: specs/coverage.md). N5b/N5c ohne N5a sind
   ausgelassen, weil der Katalog keine Kante nach N5b/N5c ausser von N5a kennt. *)
GateProfiles ==
  { {},
    {"N3a"},
    {"N4", "N6b"},
    {"N4", "N6a", "N6b"},
    {"N4", "N5a", "N6a", "N6b"},
    {"N3a", "N4", "N5a", "N6b"},
    {"N3b", "N3c", "N4", "N5a", "N5c", "N6a"},
    {"N3a", "N3b", "N4", "N5a", "N5b", "N5c", "N6a", "N6b"},
    {"N3c", "N4", "N5a", "N5b", "N5c", "N6b"},
    {"N3a", "N3c", "N4", "N5a", "N5b", "N6b"},
    {"N3b", "N4", "N5a", "N5b", "N6a", "N6b"} }

VARIABLES node,       \* aktiver Knoten oder Terminalzustand
          gates,      \* materialisierte Gate-Menge
          attempts,   \* kumulative Fix-Versuche je Rueckkante
          oneshots,   \* verbrauchte One-shot-Eskalationen
          rotations   \* verbrauchte Kontext-Rotationen

vars == <<node, gates, attempts, oneshots, rotations>>

\* Naechster Knoten auf dem Hauptpfad: der kleinste gesetzte Knoten oberhalb,
\* sonst der Pflichtknoten N7. Erzeugt genau die Vorwaertskanten des Katalogs.
Later(n) == { g \in gates : Order[g] > Order[n] }
Succ(n) ==
  IF n = "N0" THEN "N1"
  ELSE IF n = "N1" THEN "N2"
  ELSE IF Later(n) = {} THEN "N7"
  ELSE CHOOSE g \in Later(n) : \A h \in Later(n) : Order[g] <= Order[h]

\* ------------------------------------------------------------------ Typraum
TypeOK ==
  /\ node \in NodeIds \cup TerminalIds
  /\ gates \subseteq GatedNodes
  /\ attempts \in [BackEdges -> 0..MaxCounter]
  /\ oneshots \in [OneShots -> 0..MaxCounter]
  /\ rotations \in 0..MaxRotations

Init ==
  /\ node = "N0"
  /\ gates \in GateProfiles
  /\ attempts = [e \in BackEdges |-> 0]
  /\ oneshots = [e \in OneShots |-> 0]
  /\ rotations = 0

\* ----------------------------------------------------------------- Aktionen

\* Vorwaertskante ohne vorherigen Fix-Versuch an diesem Gate.
Forward ==
  /\ node \in NodeIds
  /\ node # "N7"
  /\ (node \in RetryNodes => attempts[BackFrom[node]] = 0)
  /\ node' = Succ(node)
  /\ UNCHANGED <<gates, attempts, oneshots, rotations>>

\* DER NORMALFALL (F-041): Fix hat gewirkt, das Gate besteht, der Lauf geht
\* vorwaerts. Der Fix-Zaehler wird dabei NICHT zurueckgesetzt (ADR-004; ohne
\* diese Regel traegt das Rangargument nicht — genau die Ursache von F-039).
LoopPass ==
  /\ node \in RetryNodes
  /\ attempts[BackFrom[node]] > 0
  /\ node' = Succ(node)
  /\ UNCHANGED <<gates, attempts, oneshots, rotations>>

\* Rueckkanal nach N4 mit kumulativem Limit je Kantentyp.
LoopFix ==
  /\ node \in RetryNodes
  /\ "N4" \in gates
  /\ attempts[BackFrom[node]] < AttemptLimit[BackFrom[node]]
  /\ attempts' = [attempts EXCEPT ![BackFrom[node]] = @ + 1]
  /\ node' = "N4"
  /\ UNCHANGED <<gates, oneshots, rotations>>

\* One-shot-Eskalation N5a -> N3b bzw. N5a -> N3c; das Ziel wird Gate.
Escalate ==
  /\ node = "N5a"
  /\ "N4" \in gates
  /\ \E e \in OneShots :
       /\ oneshots[e] < MaxOneShot
       /\ oneshots' = [oneshots EXCEPT ![e] = @ + 1]
       /\ node' = OneShotTarget[e]
       /\ gates' = gates \cup {OneShotTarget[e]}
  /\ UNCHANGED <<attempts, rotations>>

\* Kontext-Rotation: Selbstkante, Knoten unveraendert, begrenzt.
Rotate ==
  /\ node \in NodeIds
  /\ rotations < MaxRotations
  /\ rotations' = rotations + 1
  /\ UNCHANGED <<node, gates, attempts, oneshots>>

\* Erschoepfter Rueckkanal: Terminal blocked statt stiller 4. Versuch.
Exhausted ==
  /\ node \in RetryNodes
  /\ attempts[BackFrom[node]] = AttemptLimit[BackFrom[node]]
  /\ node' = "t_blocked"
  /\ UNCHANGED <<gates, attempts, oneshots, rotations>>

\* Stop-the-line: Direktkante * -> t_blocked.
StopTheLine ==
  /\ node \in NodeIds
  /\ node' = "t_blocked"
  /\ UNCHANGED <<gates, attempts, oneshots, rotations>>

\* Terminalwahl an N7: genau ein Terminalzustand.
Terminate ==
  /\ node = "N7"
  /\ node' \in TerminalIds
  /\ UNCHANGED <<gates, attempts, oneshots, rotations>>

(* Selbstschleife im Terminalzustand. Modellkonvention, damit CHECK_DEADLOCK
   echte Verklemmungen findet (Nicht-Terminalzustand ohne Nachfolger) statt am
   gewollten Ende auszuloesen. Ein solcher Stotterschritt aendert vars nicht und
   kann die Fairness-Annahme deshalb nicht erfuellen. *)
Terminated ==
  /\ node \in TerminalIds
  /\ UNCHANGED vars

Next ==
  \/ Forward
  \/ LoopPass
  \/ LoopFix
  \/ Escalate
  \/ Rotate
  \/ Exhausted
  \/ StopTheLine
  \/ Terminate
  \/ Terminated

(* Schwache Fairness ist noetig und ausreichend: ohne sie ist jedes unendliche
   Stottern in einem Nicht-Terminalzustand ein Gegenbeispiel (das ist F-039),
   mit ihr muss in jedem Nicht-Terminalzustand irgendwann ein Schritt fallen.
   Dass es dann nur endlich viele geben kann, ist die Aussage, die geprueft wird. *)
Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* ---------------------------------------------------------- Eigenschaften
\* Jede ist im Mutationslauf verletzbar (specs/mutation.cfg) — keine ist
\* tautologisch aus ihren eigenen Guards.

\* Rechtsgrenze je Rueckkante; strikt staerker als die Typschranke, weil
\* n6b_n4 nur 1 Versuch hat.
InvAttempts == \A e \in BackEdges : attempts[e] <= AttemptLimit[e]

\* Rechtsgrenze der One-shot-Eskalationen.
InvOneShot == \A e \in OneShots : oneshots[e] <= MaxOneShot

\* Der Lauf haelt sich nur an Pflichtknoten oder an gesetzten Gates auf.
InvGateOnly == node \in NodeIds => (node \in MandatoryNodes \/ node \in gates)

\* Temporale Eigenschaft: jeder faire Lauf erreicht einen Terminalzustand.
Termination == <>(node \in TerminalIds)

\* ------------------------------------------------------------- Mutationen
(* Jede Mutante entfernt genau eine Schutzregel. Sie sind ausschliesslich fuer
   die Gegenprobe da: In keinem Mutationslauf darf TLC gruen sein. Welche
   Mutante welche Eigenschaft bricht, steht in specs/coverage.md. *)

\* bricht TypeOK: Fix-Zaehler ohne jede Schranke.
MutFixUnbounded ==
  /\ node \in RetryNodes
  /\ "N4" \in gates
  /\ attempts' = [attempts EXCEPT ![BackFrom[node]] = @ + 1]
  /\ node' = "N4"
  /\ UNCHANGED <<gates, oneshots, rotations>>

\* bricht InvAttempts (nicht TypeOK): Auslieferungs-Rueckkante ignoriert ihr Limit 1.
MutDeliveryOverLimit ==
  /\ node = "N6b"
  /\ "N4" \in gates
  /\ attempts["n6b_n4"] < MaxCounter
  /\ attempts' = [attempts EXCEPT !["n6b_n4"] = @ + 1]
  /\ node' = "N4"
  /\ UNCHANGED <<gates, oneshots, rotations>>

\* bricht InvOneShot (nicht TypeOK): zweite One-shot-Eskalation.
MutEscalateTwice ==
  /\ node = "N5a"
  /\ "N4" \in gates
  /\ \E e \in OneShots :
       /\ oneshots[e] < MaxCounter
       /\ oneshots' = [oneshots EXCEPT ![e] = @ + 1]
       /\ node' = OneShotTarget[e]
       /\ gates' = gates \cup {OneShotTarget[e]}
  /\ UNCHANGED <<attempts, rotations>>

\* bricht InvGateOnly: Sprung auf einen nicht gesetzten Knoten.
MutSkipGate ==
  /\ node \in NodeIds
  /\ \E n \in GatedNodes :
       /\ n \notin gates
       /\ node' = n
  /\ UNCHANGED <<gates, attempts, oneshots, rotations>>

\* bricht Termination (nicht die Invarianten): der Rueckkanal setzt den
\* Fix-Zaehler zurueck. Das ist wortwoertlich die Ursache aus F-039 — mit
\* Reset entsteht der unendliche Lauf N4 -> N5a -> N4 -> ...
MutFixCounterReset ==
  /\ node \in RetryNodes
  /\ "N4" \in gates
  /\ attempts' = [attempts EXCEPT ![BackFrom[node]] = 0]
  /\ node' = "N4"
  /\ UNCHANGED <<gates, oneshots, rotations>>

MutNext ==
  \/ Next
  \/ MutFixUnbounded
  \/ MutDeliveryOverLimit
  \/ MutEscalateTwice
  \/ MutSkipGate
  \/ MutFixCounterReset

\* Sammel-Mutante (specs/mutation.cfg) und Einzelmutanten fuer die
\* Gegenprobe Eigenschaft-fuer-Eigenschaft.
SpecMutAll      == Init /\ [][MutNext]_vars /\ WF_vars(MutNext)
SpecMutType     == Init /\ [][Next \/ MutFixUnbounded]_vars /\ WF_vars(Next \/ MutFixUnbounded)
SpecMutAttempts == Init /\ [][Next \/ MutDeliveryOverLimit]_vars /\ WF_vars(Next \/ MutDeliveryOverLimit)
SpecMutOneShot  == Init /\ [][Next \/ MutEscalateTwice]_vars /\ WF_vars(Next \/ MutEscalateTwice)
SpecMutGate     == Init /\ [][Next \/ MutSkipGate]_vars /\ WF_vars(Next \/ MutSkipGate)
SpecMutTermin   == Init /\ [][Next \/ MutFixCounterReset]_vars /\ WF_vars(Next \/ MutFixCounterReset)

====
