---- MODULE workflow ----
(*
  Abstraktes CFG-Modell für agent-rules Terminierungsbeweis.
  Prüfung: java -cp tla2tools.jar tlc2.TLC -config specs/workflow.cfg specs/workflow.tla
*)

EXTENDS Naturals, FiniteSets

CONSTANTS MaxCycle, MaxDepth, MaxNode
ASSUME MaxCycle = 3
ASSUME MaxDepth = 4
ASSUME MaxNode = 7

VARIABLES phase, cfg_node, cycle, depth, in_loop, terminal

Phases == {"bootstrapping", "executing", "done", "blocked"}
Terminals == {"done", "blocked"}

TypeOK ==
  /\ phase \in Phases
  /\ cfg_node \in 0..MaxNode
  /\ cycle \in 0..MaxCycle
  /\ depth \in 0..MaxDepth
  /\ in_loop \in BOOLEAN
  /\ terminal \in BOOLEAN

Init ==
  /\ phase = "bootstrapping"
  /\ cfg_node = 0
  /\ cycle = 0
  /\ depth = 0
  /\ in_loop = FALSE
  /\ terminal = FALSE

Forward ==
  /\ ~terminal
  /\ ~in_loop
  /\ cfg_node < MaxNode
  /\ cfg_node' = cfg_node + 1
  /\ cycle' = 0
  /\ depth' = depth
  /\ phase' = IF cfg_node' = MaxNode THEN "done" ELSE phase
  /\ terminal' = (cfg_node' = MaxNode)
  /\ in_loop' = FALSE
  /\ UNCHANGED <<>>

EnterLoop ==
  /\ ~terminal
  /\ cfg_node \in {4, 5, 6}
  /\ ~in_loop
  /\ in_loop' = TRUE
  /\ cycle' = 1
  /\ cfg_node' = 4
  /\ UNCHANGED <<phase, depth, terminal>>

LoopRetry ==
  /\ ~terminal
  /\ in_loop
  /\ cycle < MaxCycle
  /\ cycle' = cycle + 1
  /\ cfg_node' = 4
  /\ UNCHANGED <<phase, depth, terminal, in_loop>>

LoopExhaust ==
  /\ ~terminal
  /\ in_loop
  /\ cycle = MaxCycle
  /\ phase' = "blocked"
  /\ terminal' = TRUE
  /\ in_loop' = FALSE
  /\ UNCHANGED <<cfg_node, cycle, depth>>

Spawn ==
  /\ ~terminal
  /\ depth < MaxDepth
  /\ depth' = depth + 1
  /\ UNCHANGED <<phase, cfg_node, cycle, in_loop, terminal>>

Next ==
  \/ Forward
  \/ EnterLoop
  \/ LoopRetry
  \/ LoopExhaust
  \/ Spawn

Spec == Init /\ [][Next]_<<phase, cfg_node, cycle, depth, in_loop, terminal>>

InvCycle == cycle <= MaxCycle
InvDepth == depth <= MaxDepth
InvTerminal == terminal => phase \in Terminals

THEOREM Spec => []InvCycle
THEOREM Spec => []InvDepth
THEOREM Spec => []InvTerminal

====
