#!/usr/bin/env bash
# validate-handovers.sh — Frontmatter gegen schemas/handover.schema.json
# Exit: 0 PASS | 1 FAIL | 2 NICHT NACHGEWIESEN
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/schemas/handover.schema.json"
TARGET="${1:-${ROOT}/runtime/handovers}"
ALLOW_SKIP=0

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
skip() { printf 'NICHT NACHGEWIESEN: %s\n' "$*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-skip) ALLOW_SKIP=1; shift ;;
    --) shift; break ;;
    -*) die "unbekannt: $1" ;;
    *) TARGET="$1"; shift ;;
  esac
done

command -v jq >/dev/null 2>&1 || skip "jq fehlt"
command -v npx >/dev/null 2>&1 || skip "npx fehlt"
[[ -f "$SCHEMA" ]] || die "Schema fehlt: $SCHEMA"

extract_frontmatter() {
  local f="$1" out="$2"
  awk '
    BEGIN { in_fm=0; n=0 }
    /^---[[:space:]]*$/ {
      n++
      if (n==1) { in_fm=1; next }
      if (n==2) { exit }
    }
    in_fm { print }
  ' "$f" >"$out"
}

# Nested YAML→JSON. PyYAML ist Pflicht; ohne Parser kein PASS (LAW-DOD).
yaml_to_json() {
  python3 - "$1" <<'PY'
import json, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
try:
    import yaml
except ImportError:
    print("NICHT NACHGEWIESEN: PyYAML fehlt", file=sys.stderr)
    raise SystemExit(2)
data = yaml.safe_load(text) or {}
print(json.dumps(data))
PY
}

shopt -s nullglob
files=()
if [[ -f "$TARGET" ]]; then
  files=("$TARGET")
elif [[ -d "$TARGET" ]]; then
  files=("$TARGET"/*.md)
else
  printf 'PASS: kein Ziel (%s)\n' "$TARGET"
  exit 0
fi

if ((${#files[@]} == 0)); then
  printf 'PASS: keine Handover-Markdown-Dateien in %s\n' "$TARGET"
  exit 0
fi

bad=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  # no-inline-logs: reject huge fenced log dumps (>200 lines of content)
  lines="$(wc -l <"$f")"
  max="$(jq -r '.caps.handover_max_lines' "${ROOT}/config/policy-defaults.json")"
  if (( lines > max )); then
    printf 'FAIL %s: %s Zeilen > Cap %s\n' "$f" "$lines" "$max"
    bad=$((bad + 1))
    continue
  fi
  fm="${tmp}/fm.yaml"
  js="${tmp}/fm.json"
  extract_frontmatter "$f" "$fm"
  if [[ ! -s "$fm" ]]; then
    printf 'FAIL %s: kein YAML-Frontmatter\n' "$f"
    bad=$((bad + 1))
    continue
  fi
  yerr="${tmp}/yaml.err"
  set +e
  yaml_to_json "$fm" >"$js" 2>"$yerr"
  yrc=$?
  set -e
  if (( yrc == 2 )); then
    skip "PyYAML fehlt"
  elif (( yrc != 0 )); then
    printf 'FAIL %s: YAML-Parse\n' "$f"
    bad=$((bad + 1))
    continue
  fi
  if ! npx -y -p ajv-cli@5 -p ajv-formats ajv validate \
      -s "$SCHEMA" -d "$js" --spec=draft2020 -c ajv-formats >/dev/null 2>&1; then
    printf 'FAIL %s: Schema\n' "$f"
    bad=$((bad + 1))
  else
    printf 'PASS %s\n' "$f"
  fi
done

(( bad == 0 )) && printf 'PASS validate-handovers (%s Dateien)\n' "${#files[@]}"
(( bad == 0 ))
