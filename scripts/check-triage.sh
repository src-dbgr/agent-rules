#!/usr/bin/env bash
# check-triage.sh — prueft die Triage-Algebra v2 (ADR-003) gegen die Fixtures.
#
# Sprache: Bash + jq. Begruendung: die Algebra ist eine Mengenoperation ueber JSON
# (Vereinigung von Gate-Listen), jq ist dafuer die direkte Notation und laut
# Annahme A-06 vorhanden. Python waere eine zweite Laufzeit fuer denselben Zweck.
#
# SSoT: Klassen, Flags und Gate-Matrix werden AUSSCHLIESSLICH aus
# manifest.json#/triage gelesen. Dieses Skript enthaelt keine eigene Kopie der
# Tabelle — sonst pruefte es sich selbst.
#
# Geprueft wird (8 Pruefungen):
#   1  ids-unique                 IDs der Faelle sind eindeutig
#   2  vocabulary                 jede Klasse/jedes Flag steht im Manifest
#   3  gate-derivation            Gates(Fall) = Gates(Klasse) u. Gates(Flags) u. {N3a}
#   4  first-match-order          also_matches hat stets die hoehere Regelnummer
#   5  class-coverage             alle 6 Klassen belegt
#   6  flag-coverage              alle 9 Flags belegt
#   7  min-count                  Fallzahl >= enforcement.triage_fixtures_min
#   8  gate-sets-distinct         die 6 Klassen-Gate-Sets sind paarweise verschieden
#   9  criteria-non-circular      kein Ausloeser nennt einen Klassennamen
#
# BEKANNTE GRENZE (ehrlich, nicht umgehbar): Geprueft wird das VERFAHREN
# (Ableitung, Ordnung, Totalitaet, Nicht-Zirkularitaet), nicht der KLASSIFIKATOR.
# Dass ein LLM aus `prompt` dieselbe `expected_class` waehlt, kann dieses Skript
# nicht feststellen (Annahme A-12); genau deshalb existieren die Fixtures als
# Regressionsnetz fuer Menschen und Review.
#
# Exit: 0 = alles PASS · 1 = mindestens ein FAIL · 2 = mindestens ein SKIP
#       ("NICHT NACHGEWIESEN") ohne --allow-skip. SKIP gilt nie als PASS.
set -uo pipefail

FIXTURES="tests/fixtures/triage-cases.json"
MANIFEST="manifest.json"
CONFIG="config/policy-defaults.json"
ALLOW_SKIP=0
VERBOSE=1

usage() {
  cat <<'EOF'
Aufruf: scripts/check-triage.sh [Optionen]
  --file <pfad>    Fixture-Datei (Default: tests/fixtures/triage-cases.json)
  --manifest <p>   Manifest mit der Gate-Matrix (Default: manifest.json)
  --allow-skip     degradiert Exit 2 auf 0 (lokal; in CI verboten)
  --quiet          nur Zusammenfassung, keine Zeile je Fall
  --help           diese Hilfe
Exit: 0 PASS · 1 FAIL · 2 NICHT NACHGEWIESEN (SKIP)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FIXTURES="${2:?--file braucht einen Pfad}"; shift 2 ;;
    --manifest) MANIFEST="${2:?--manifest braucht einen Pfad}"; shift 2 ;;
    --config) CONFIG="${2:?--config braucht einen Pfad}"; shift 2 ;;
    --allow-skip) ALLOW_SKIP=1; shift ;;
    --quiet) VERBOSE=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'FAIL: unbekannte Option %s\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
done

PASS_N=0; FAIL_N=0; SKIP_N=0
pass() { PASS_N=$((PASS_N + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_N=$((FAIL_N + 1)); printf 'FAIL: %s\n' "$1"; }
skip() { SKIP_N=$((SKIP_N + 1)); printf 'NICHT NACHGEWIESEN: %s (Werkzeug %s fehlt)\n' "$1" "$2"; }

if [ "$ALLOW_SKIP" = 1 ] && [ -n "${CI:-}" ]; then
  printf 'FAIL: --allow-skip ist in CI verboten (enforcement.allow_skip_in_ci=false)\n' >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  skip "check-triage (alle Pruefungen)" "jq"
  printf '\nZusammenfassung: %d PASS, %d FAIL, %d NICHT NACHGEWIESEN\n' "$PASS_N" "$FAIL_N" "$SKIP_N"
  [ "$ALLOW_SKIP" = 1 ] && exit 0
  exit 2
fi

for f in "$FIXTURES" "$MANIFEST"; do
  if [ ! -f "$f" ]; then fail "Pflichtdatei fehlt: $f"; fi
done
if [ "$FAIL_N" -gt 0 ]; then
  printf '\nZusammenfassung: %d PASS, %d FAIL, %d NICHT NACHGEWIESEN\n' "$PASS_N" "$FAIL_N" "$SKIP_N"
  exit 1
fi
for f in "$FIXTURES" "$MANIFEST"; do
  jq empty "$f" 2>/dev/null || { fail "kein gueltiges JSON: $f"; }
done
if [ "$FAIL_N" -gt 0 ]; then
  printf '\nZusammenfassung: %d PASS, %d FAIL, %d NICHT NACHGEWIESEN\n' "$PASS_N" "$FAIL_N" "$SKIP_N"
  exit 1
fi

# --- 1 IDs eindeutig ---------------------------------------------------------
dupes="$(jq -r '[.cases[].id] | group_by(.) | map(select(length > 1) | .[0]) | join(", ")' "$FIXTURES")"
if [ -z "$dupes" ]; then pass "ids-unique"; else fail "ids-unique: doppelte IDs: $dupes ($FIXTURES)"; fi

# --- 2 Vokabular aus dem Manifest -------------------------------------------
unknown="$(jq -r --slurpfile m "$MANIFEST" '
  ([$m[0].triage.classes[].id]) as $cls
  | ([$m[0].triage.flags[].id]) as $flg
  | [ .cases[]
      | . as $c
      | (if ($cls | index($c.expected_class)) == null
         then "\($c.id): Klasse \($c.expected_class)" else empty end),
        ($c.expected_flags[] | select(($flg | index(.)) == null) | "\($c.id): Flag \(.)")
    ] | join("; ")' "$FIXTURES")"
if [ -z "$unknown" ]; then pass "vocabulary (6 Klassen, 9 Flags aus $MANIFEST)"; else fail "vocabulary: $unknown"; fi

# --- 3 Gate-Ableitung je Fall ------------------------------------------------
# Gates = Gates(Klasse) u. { Gates(Flag) } u. ({N3a} falls needs_external_source)
derive_report="$(jq -r --slurpfile m "$MANIFEST" '
  ($m[0].triage.gate_matrix.classes) as $cg
  | ($m[0].triage.gate_matrix.flags) as $fg
  | .cases[]
  | . as $c
  | (($cg[$c.expected_class] // [])
     + [ $c.expected_flags[] | $fg[.] // "??unknown-flag-gate" ]
     + (if ($c.needs_external_source // false) then ["N3a"] else [] end)
     | unique) as $derived
  | ($c.expected_gates | unique) as $expected
  | if $derived == $expected
    then "OK\t\($c.id)\t\($c.expected_class)\t[\($c.expected_flags | join(","))]\t\($derived | join(" "))"
    else "XX\t\($c.id)\t\($c.expected_class)\t[\($c.expected_flags | join(","))]\terwartet: \($expected | join(" ")) | abgeleitet: \($derived | join(" "))"
    end' "$FIXTURES")"
bad_cases=0
while IFS=$'\t' read -r mark id cls flags gates; do
  [ -z "${mark:-}" ] && continue
  if [ "$mark" = "OK" ]; then
    [ "$VERBOSE" = 1 ] && printf '  ok   %-6s %-9s %-18s %s\n' "$id" "$cls" "$flags" "$gates"
  else
    bad_cases=$((bad_cases + 1))
    printf '  BAD  %-6s %-9s %-18s %s\n' "$id" "$cls" "$flags" "$gates"
  fi
done <<< "$derive_report"
total_cases="$(jq -r '.cases | length' "$FIXTURES")"
if [ "$bad_cases" = 0 ]; then
  pass "gate-derivation ($total_cases Faelle, High-Water-Mark = Vereinigung)"
else
  fail "gate-derivation: $bad_cases von $total_cases Faellen weichen ab ($FIXTURES)"
fi

# --- 4 Erst-Treffer-Ordnung --------------------------------------------------
order_bad="$(jq -r --slurpfile m "$MANIFEST" '
  ([$m[0].triage.classes[] | {key: .id, value: .rule_no}] | from_entries) as $rn
  | [ .cases[] | select(.also_matches != null) | . as $c
      | ($rn[$c.expected_class]) as $own
      | ($c.also_matches | map($rn[.]) | min) as $other
      | select($own >= $other)
      | "\($c.id): \($c.expected_class) (Regel \($own)) ist nicht vor \($c.also_matches | join(","))"
    ] | join("; ")' "$FIXTURES")"
order_n="$(jq -r '[.cases[] | select(.also_matches != null)] | length' "$FIXTURES")"
if [ "$order_n" = 0 ]; then
  fail "first-match-order: kein Fall mit also_matches — die Ordnung waere unbelegt ($FIXTURES)"
elif [ -z "$order_bad" ]; then
  pass "first-match-order ($order_n Ordnungstest(s))"
else
  fail "first-match-order: $order_bad"
fi

# --- 5/6 Abdeckung -----------------------------------------------------------
miss_cls="$(jq -r --slurpfile m "$MANIFEST" '
  ([$m[0].triage.classes[].id]) - ([.cases[].expected_class] | unique) | join(", ")' "$FIXTURES")"
if [ -z "$miss_cls" ]; then pass "class-coverage (alle 6)"; else fail "class-coverage: unbelegt: $miss_cls"; fi

miss_flg="$(jq -r --slurpfile m "$MANIFEST" '
  ([$m[0].triage.flags[].id]) - ([.cases[].expected_flags[]] | unique) | join(", ")' "$FIXTURES")"
if [ -z "$miss_flg" ]; then pass "flag-coverage (alle 9)"; else fail "flag-coverage: unbelegt: $miss_flg"; fi

# --- 7 Mindestanzahl aus der Zahlen-SSoT ------------------------------------
if [ -f "$CONFIG" ]; then
  min_req="$(jq -r '.enforcement.triage_fixtures_min // 20' "$CONFIG")"
else
  min_req="$(jq -r '.coverage.min_required // 20' "$FIXTURES")"
  printf '  Hinweis: %s fehlt, Mindestanzahl aus der Fixture-Datei (%s)\n' "$CONFIG" "$min_req"
fi
if [ "$total_cases" -ge "$min_req" ]; then
  pass "min-count ($total_cases >= $min_req)"
else
  fail "min-count: $total_cases < $min_req (config/policy-defaults.json#/enforcement/triage_fixtures_min)"
fi

# --- 8 Gate-Sets paarweise verschieden (AK-029) ------------------------------
dup_sets="$(jq -r '
  [ .triage.gate_matrix.classes | to_entries[] | {k: .key, v: (.value | unique)} ]
  | group_by(.v) | map(select(length > 1) | map(.k) | join("="))
  | join("; ")' "$MANIFEST")"
if [ -z "$dup_sets" ]; then pass "gate-sets-distinct (6 Klassen)"; else fail "gate-sets-distinct: identische Gate-Sets: $dup_sets ($MANIFEST)"; fi

# --- 9 Nicht-Zirkularitaet der Ausloeser (AK-032) ----------------------------
circ="$(jq -r --slurpfile m "$MANIFEST" '
  ([$m[0].triage.classes[].id] + ["fast-track","standard-track","deep-track","fast_track","standard_track","deep_track","track"]) as $bad
  | [ (.class_order // [])[] as $r
      | $bad[] as $w
      | select(($r.trigger | ascii_downcase) | test("(^|[^a-z0-9_])" + ($w | ascii_downcase) + "([^a-z0-9_]|$)"))
      | "Regel \($r.rule_no) (\($r.class)) nennt \"\($w)\""
    ] | unique | join("; ")' "$FIXTURES")"
order_rows="$(jq -r '(.class_order // []) | length' "$FIXTURES")"
if [ "$order_rows" = 0 ]; then
  fail "criteria-non-circular: class_order fehlt in $FIXTURES — Zirkularitaet waere ungeprueft"
elif [ -z "$circ" ]; then
  pass "criteria-non-circular ($order_rows Ausloeser ohne Klassen-/Track-Namen)"
else
  fail "criteria-non-circular: $circ ($FIXTURES)"
fi

printf '\nZusammenfassung: %d PASS, %d FAIL, %d NICHT NACHGEWIESEN (Faelle: %s)\n' \
  "$PASS_N" "$FAIL_N" "$SKIP_N" "$total_cases"
printf 'Grenze: geprueft ist die Algebra, nicht der Klassifikator (Annahme A-12).\n'

if [ "$FAIL_N" -gt 0 ]; then exit 1; fi
if [ "$SKIP_N" -gt 0 ] && [ "$ALLOW_SKIP" = 0 ]; then exit 2; fi
exit 0
