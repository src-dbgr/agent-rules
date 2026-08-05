#!/usr/bin/env bash
# migrate-state.sh — State-Migration v1.3.1 -> 2.0.0 (ADR-010 §3).
#
# Sprache: Bash + jq. Die Migration ist eine reine JSON-Transformation; alle
# Abbildungstabellen (Track->Klasse, Signal->Flag, Knoten-ID, Phase, Ergebnis)
# stehen in manifest.json#/migration und NICHT in diesem Skript — sonst gaebe es
# zwei Wahrheiten. Die Transformation ist idempotent: ein bereits migrierter
# Zustand (schema_version 2.x) wird unveraendert durchgereicht.
#
# Aufruf:
#   migrate-state.sh <alt>                  Dry-Run: Bericht, keine Datei geschrieben
#   migrate-state.sh <alt> <neu>            schreibt nach <neu> (explizites Ziel)
#   migrate-state.sh <alt> --write          schreibt nach runtime/state/<orchestrator_id>.json
#   migrate-state.sh <alt> <neu> --dry-run  erzwingt Dry-Run trotz Zielpfad
# Default ist Dry-Run: ohne Zielpfad und ohne --write wird nichts geschrieben.
# Ein ausdruecklich genannter Zielpfad IST die Schreibanweisung (AK-112).
#
# Exit-Semantik (einheitlich, ADR-009 §2):
#   0  Migration erfolgreich (oder Dry-Run ohne Befund)
#   1  Migration gescheitert (Eingabe unlesbar, Ergebnis nicht schema-valide,
#      Zielpfad nicht schreibbar) — die Alt-Datei bleibt in jedem Fall unveraendert
#   2  Ergebnis NICHT NACHGEWIESEN, weil das Validierungswerkzeug (npx/ajv) fehlt
#      — ohne --allow-skip. Die Datei wird dann trotzdem geschrieben, aber als
#      unbestaetigt gemeldet.
#
# Bekannte Grenze (bewusst, ADR-010 §3 Schritt 4): cfg.active_node wird ueber die
# ausfuehrliche Alt-Zaehlung N0..N12 abgebildet. Zustaende, die die Kern-Zaehlung
# des alten workflow-cfg.md benutzten (dort war N7 = Aggregation), sind daraus
# nicht rekonstruierbar. Solche Faelle werden im Bericht als ENTSCHEIDUNG NOETIG
# ausgewiesen und nicht geraten.
set -uo pipefail

SRC=""
DST=""
MODE="dry-run"
ALLOW_SKIP=0
MANIFEST="manifest.json"
SCHEMA="schemas/agent-state.schema.json"

usage() { sed -n '3,32p' "$0"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --write) MODE="write"; shift ;;
    --dry-run) MODE="forced-dry-run"; shift ;;
    --allow-skip) ALLOW_SKIP=1; shift ;;
    --manifest) MANIFEST="${2:?}"; shift 2 ;;
    --schema) SCHEMA="${2:?}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    -*) printf 'FAIL: unbekannte Option %s\n' "$1" >&2; exit 1 ;;
    *)
      if [ -z "$SRC" ]; then SRC="$1"
      elif [ -z "$DST" ]; then DST="$1"; [ "$MODE" = "dry-run" ] && MODE="write"
      else printf 'FAIL: zu viele Argumente (%s)\n' "$1" >&2; exit 1; fi
      shift ;;
  esac
done

if [ "$ALLOW_SKIP" = 1 ] && [ -n "${CI:-}" ]; then
  printf 'FAIL: --allow-skip ist in CI verboten\n' >&2; exit 1
fi
[ -n "$SRC" ] || { usage >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'FAIL: jq fehlt — die Migration ist eine jq-Transformation\n' >&2; exit 1; }
for f in "$SRC" "$MANIFEST"; do
  [ -f "$f" ] || { printf 'FAIL: Datei fehlt: %s\n' "$f" >&2; exit 1; }
  jq empty "$f" >/dev/null 2>&1 || { printf 'FAIL: kein gueltiges JSON: %s\n' "$f" >&2; exit 1; }
done
[ "$MODE" = "forced-dry-run" ] && MODE="dry-run"

# .json-Endung ist Pflicht: ajv-cli erkennt das Format an der Endung.
WORK="$(mktemp -d)"
TMP="$WORK/state.json"; REPORT="$WORK/report.txt"
trap 'rm -rf "$WORK"' EXIT

# --- Transformation ----------------------------------------------------------
# Der Bericht entsteht in derselben Transformation ($report), damit Bericht und
# Ergebnis nicht auseinanderlaufen koennen.
jq --slurpfile m "$MANIFEST" -f /dev/stdin "$SRC" > "$TMP" <<'JQEOF' || { printf 'FAIL: Transformation gescheitert\n' >&2; exit 1; }
($m[0].migration) as $mig
| ($m[0].cfg.nodes) as $nodes
| . as $old
| ($old.schema_version // "unbekannt") as $oldver
| if ($oldver | test("^2\\.")) then
    . + {"__report__": ["UNVERAENDERT: schema_version \($oldver) ist bereits v2 (idempotent)"]}
  else
  ([] ) as $rep
  # --- Schritt 2: Track/Decision -> Klasse + Flags
  | (($old.cfg.track // $old.triage.decision // "standard") | tostring) as $trackkey
  | ($mig.track_map[$trackkey] // {change_class: "feature", signals: []}) as $tm
  | (($old.triage.signals // []) | map($mig.signal_map[.] // null)) as $mapped
  | (($old.triage.signals // []) | map(select($mig.signal_map[.] == null))) as $dropped
  | (($tm.signals + ($mapped | map(select(. != null)))) | unique) as $signals
  # --- Schritt 4: Knoten-IDs
  | (($old.cfg.active_node | tostring)) as $an_old
  | ($mig.node_map[$an_old] // null) as $an_new
  | (($old.cfg.completed_nodes // []) | map($mig.node_map[(. | tostring)] // null) | map(select(. != null)) | unique) as $done_nodes
  | ($nodes | map(select(.id == ($an_new // "N1"))) | first) as $an_node
  # --- Schritt 5/6: Budget und Zyklen
  | (($old.context_budget.orchestrator_utilization_percent // null)) as $util
  | (($old.cycles.active_loop // "none")) as $loop
  | (($old.cycles.current_attempt // 0)) as $att
  | {
      "$comment": "Migriert von schema_version \($oldver) durch scripts/migrate-state.sh (ADR-010). Zaehler ohne Alt-Entsprechung starten bei 0 - das ist eine Untererfassung, keine Messung.",
      schema_version: $mig.to_version,
      orchestrator_id: $old.orchestrator_id,
      orchestrator_lineage: ($old.orchestrator_lineage // []),
      original_user_prompt: $old.original_user_prompt,
      phase: ($mig.phase_map[($old.phase // "executing")] // "executing"),
      cfg: {
        active_node: ($an_new // "N1"),
        active_node_name: (($an_node.name) // "BOOTSTRAP"),
        completed_nodes: $done_nodes
      },
      triage: ({
        change_class: $tm.change_class,
        signals: $signals,
        rationale: "Migriert aus v1.3.1: track=\($old.cfg.track // "-"), decision=\($old.triage.decision // "-") (Abbildung: manifest.json#/migration/track_map). Klasse und Flags sind bei der naechsten Triage zu bestaetigen."
      } + (if $tm.change_class == "incident" then {deferred_gates: []} else {} end)),
      tree: {
        current_depth: ($old.tree.current_depth // 0),
        max_depth: 4,
        max_fanout: 4,
        total_spawned: ($old.tree.total_spawned // 0),
        total_spawned_before_rotation: ($old.tree.total_spawned // 0)
      },
      cycles: {
        attempts: {
          test_fix: (if $loop == "test_fix" then $att else 0 end),
          ui_fix: (if $loop == "ui_fix" then $att else 0 end),
          security_fix: (if $loop == "security_fix" then $att else 0 end),
          delivery_fix: 0
        },
        one_shot_escalations: {
          requirements_gap: ($old.cycles.one_shot_escalations.requirements_gap_n5_n3b // $old.cycles.one_shot_escalations.requirements_gap // false),
          architecture_drift: ($old.cycles.one_shot_escalations.architecture_drift_n5_n3c // $old.cycles.one_shot_escalations.architecture_drift // false)
        },
        rotations: 0,
        loop_history: (($old.cycles.loop_history // []) | map(
            select(.loop != null and .attempt != null and .timestamp != null)
            | {loop: .loop, attempt: .attempt,
               outcome: ($mig.outcome_map[(.outcome // "fail")] // "fail"),
               timestamp: .timestamp}
            + (if .from_node then {from_node: ($mig.node_map[(.from_node|tostring)] // .from_node)} else {} end)
            + (if .to_node then {to_node: ($mig.node_map[(.to_node|tostring)] // .to_node)} else {} end)
          ))
      },
      budget: ({
        files_read: 0, bytes_read: 0, tool_calls: 0, turns: 0,
        subagents_spawned: ($old.tree.total_spawned // 0),
        rotations: 0, artifact_bytes: 0
      } + {utilization_percent: (if $util == null then "unavailable" else $util end)}),
      running_sub_agents: (($old.running_sub_agents // []) | map(
          . as $s
          | {id: $s.id, role: ($s.role // "developer"), depth: ($s.depth // 1),
             status: ($s.status // "running"),
             cfg_node: ($mig.node_map[($s.cfg_node | tostring)] // "N4"),
             spawned_at: ($s.spawned_at // $old.timestamps.created_at)}
          + (if $s.parent_id then {parent_id: $s.parent_id} else {} end)
        )),
      handovers: [],
      artifacts: (($old.artifacts // {}) | with_entries(
          .value |= {path: .path, type: (.type // "unknown"),
                     created_at: (.created_at // "1970-01-01T00:00:00Z")}
                    + (if .role then {role: .role} else {} end)
        )),
      memory: ($old.memory // {active: [], pending_writes: [],
               poisoning_checks: {source_validated: false, session_isolated: false,
                                  integrity_baseline: false, injection_scan: "not_run",
                                  policy_action: "allow"}}),
      dod_gates: (($old.dod_gates // {}) | with_entries(
          .key |= ($mig.node_map[(. | ltrimstr("N"))] // .)
        )),
      blockers: ($old.blockers // []),
      vcs: {default_branch: "main", branches: []},
      delivery: {node: "N6b", status: "pending"},
      timestamps: {
        created_at: ($old.timestamps.created_at // "1970-01-01T00:00:00Z"),
        updated_at: ($old.timestamps.updated_at // $old.timestamps.created_at // "1970-01-01T00:00:00Z")
      }
    }
  | . as $new
  | .["__report__"] = (
      ["schema_version: \($oldver) -> \($mig.to_version)",
       "triage: track=\($old.cfg.track // "-") / decision=\($old.triage.decision // "-") -> change_class=\($new.triage.change_class), signals=\($new.triage.signals | join(",") | if . == "" then "keine" else . end)",
       "cfg.active_node: \($an_old) -> \($new.cfg.active_node) (\($new.cfg.active_node_name))",
       "cfg.completed_nodes: \(($old.cfg.completed_nodes // []) | length) -> \($new.cfg.completed_nodes | length) eindeutige Knoten",
       "phase: \($old.phase // "-") -> \($new.phase)",
       "budget: context_budget -> budget, Zaehler auf 0, utilization_percent=\($new.budget.utilization_percent | tostring)",
       "cycles: current_attempt=\($att)/active_loop=\($loop) -> attempts=\($new.cycles.attempts | tojson), rotations=0",
       "dod_gates: \(($old.dod_gates // {}) | keys | join(",")) -> \($new.dod_gates | keys | join(","))",
       "neu angelegt: vcs (default_branch=main), delivery (N6b/pending), orchestrator_lineage, handovers"]
      + ([$mig.removed_fields[] | "entfernt: \(.)"])
      + (if ($dropped | length) > 0 then ["VERWORFEN: unbekannte Signale \($dropped | join(", ")) - kein Flag im 9er-Raum (Blocker-Eintrag noetig)"] else [] end)
      + (if $an_new == null then ["ENTSCHEIDUNG NOETIG: cfg.active_node=\($an_old) steht nicht in der Abbildungstabelle; ersatzweise N1 gesetzt"] else [] end)
      + (if (($old.cfg.active_node | type) == "number" and ($old.cfg.active_node) <= 7) then ["ENTSCHEIDUNG NOETIG: \($an_old) ist in beiden Alt-Zaehlungen belegt (Kern N0..N7 und ausfuehrlich N0..N12). Abgebildet wurde die ausfuehrliche Zaehlung (ADR-010 §3 Schritt 4) - bitte bestaetigen"] else [] end)
      + (if (($old.dod_gates // {}) | keys | map(select(test("^N(8|9|1[0-2])$"))) | length) > 0 then ["Hinweis: Alt-Gates N8..N12 wurden auf die neuen IDs abgebildet; bei Kollision gewinnt der letzte Eintrag"] else [] end)
    )
  end
JQEOF

jq -r '.__report__[]' "$TMP" > "$REPORT" 2>/dev/null || true
jq 'del(.__report__)' "$TMP" > "$TMP.clean" && mv "$TMP.clean" "$TMP"

# --- Zielpfad ----------------------------------------------------------------
if [ -z "$DST" ]; then
  OID="$(jq -r '.orchestrator_id' "$TMP")"
  DST="runtime/state/${OID}.json"
fi

printf '=== Migrationsbericht: %s -> %s ===\n' "$SRC" "$DST"
sed 's/^/  - /' "$REPORT"
printf '  - Modus: %s\n' "$(if [ "$MODE" = write ]; then echo "SCHREIBEN"; else echo "DRY-RUN (keine Datei wird geschrieben)"; fi)"
printf '  - Alt-Datei %s wird NICHT geloescht (ADR-010 §3 Schritt 8); Entfernen ist eine bewusste, getrennte Handlung\n' "$SRC"

# --- Validierung (Schritt 9) -------------------------------------------------
VALID_RC=0
if [ ! -f "$SCHEMA" ]; then
  printf 'FAIL: Schema fehlt: %s\n' "$SCHEMA"
  exit 1
fi
if command -v npx >/dev/null 2>&1; then
  if npx -y -p ajv-cli@5 -p ajv-formats ajv validate -s "$SCHEMA" -d "$TMP" \
       --spec=draft2020 -c ajv-formats >/tmp/migrate-ajv.log 2>&1; then
    printf 'PASS: Ergebnis ist valide gegen %s\n' "$SCHEMA"
  else
    printf 'FAIL: Ergebnis ist NICHT valide gegen %s\n' "$SCHEMA"
    sed 's/^/    /' /tmp/migrate-ajv.log | tail -25
    printf 'Alt-Datei %s bleibt unveraendert; es wurde nichts geschrieben.\n' "$SRC"
    exit 1
  fi
else
  printf 'NICHT NACHGEWIESEN: Schema-Validierung des Ergebnisses (Werkzeug npx/ajv fehlt)\n'
  VALID_RC=2
fi

if [ "$MODE" != "write" ]; then
  printf 'Dry-Run beendet. Mit einem Zielpfad oder --write schreiben.\n'
  [ "$VALID_RC" = 2 ] && [ "$ALLOW_SKIP" = 0 ] && exit 2
  exit 0
fi

mkdir -p "$(dirname "$DST")" || { printf 'FAIL: Zielverzeichnis nicht anlegbar: %s\n' "$(dirname "$DST")" >&2; exit 1; }
if [ -f "$DST" ]; then
  BAK="${DST}.bak-$(date -u +%Y%m%dT%H%M%SZ)"
  cp "$DST" "$BAK" || { printf 'FAIL: Backup nicht anlegbar\n' >&2; exit 1; }
  printf 'Backup: %s\n' "$BAK"
fi
cp "$TMP" "$DST" || { printf 'FAIL: Schreiben nach %s gescheitert\n' "$DST" >&2; exit 1; }
printf 'GESCHRIEBEN: %s\n' "$DST"
if [ "$VALID_RC" = 2 ] && [ "$ALLOW_SKIP" = 0 ]; then
  printf 'Ergebnis ist geschrieben, aber unbestaetigt.\n'
  exit 2
fi
exit 0
