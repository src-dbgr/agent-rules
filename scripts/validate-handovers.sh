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

# Minimal YAML→JSON for flat key: value frontmatter (strings/numbers/booleans)
yaml_flat_to_json() {
  python3 - "$1" <<'PY'
import json, sys, re
path = sys.argv[1]
data = {}
with open(path, encoding="utf-8") as fh:
    for raw in fh:
        line = raw.rstrip("\n")
        if not line or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k = k.strip()
        v = v.strip().strip('"').strip("'")
        if v.lower() in ("true", "false"):
            data[k] = v.lower() == "true"
        else:
            try:
                if re.fullmatch(r"-?\d+", v):
                    data[k] = int(v)
                elif re.fullmatch(r"-?\d+\.\d+", v):
                    data[k] = float(v)
                else:
                    data[k] = v
            except Exception:
                data[k] = v
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
  yaml_flat_to_json "$fm" >"$js"
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
