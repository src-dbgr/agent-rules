#!/usr/bin/env bash
# Zählt Triage-Fixtures und prüft Klassen-Abdeckung.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIN=20
COVER=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --min) MIN="${2:-20}"; shift 2 ;;
    --cover-all) COVER=1; shift ;;
    *) shift ;;
  esac
done
command -v jq >/dev/null || { echo "NICHT NACHGEWIESEN: jq"; exit 2; }
FILE="$ROOT/tests/fixtures/triage-cases.json"
n="$(jq 'if type=="array" then length else (.cases|length) end' "$FILE")"
echo "fixtures=$n min=$MIN"
(( n >= MIN )) || { echo "FAIL: zu wenige Fixtures"; exit 1; }
if (( COVER == 1 )); then
  missing=0
  for c in answer chore revert spike incident feature; do
    if ! jq -e --arg c "$c" '
      (if type=="array" then . else .cases end)
      | map(select((.erwartete_klasse // .expected_class // .class) == $c))
      | length > 0
    ' "$FILE" >/dev/null; then
      echo "FAIL: Klasse $c nicht in Fixtures"
      missing=1
    fi
  done
  (( missing == 0 )) || exit 1
fi
echo "PASS triage-fixtures-check"
