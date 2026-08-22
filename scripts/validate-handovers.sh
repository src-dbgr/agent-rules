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

# Nested YAML→JSON (scalars, lists, maps). Prefer PyYAML; else a small subset parser.
yaml_to_json() {
  python3 - "$1" <<'PY'
import json, sys, re
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
try:
    import yaml
    data = yaml.safe_load(text) or {}
    print(json.dumps(data))
    raise SystemExit(0)
except ImportError:
    pass

def coerce(v):
    v = v.strip().strip('"').strip("'")
    if v.lower() in ("true", "false"):
        return v.lower() == "true"
    if v.lower() in ("null", "~", ""):
        return None
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if re.fullmatch(r"-?\d+\.\d+", v):
        return float(v)
    return v

def parse(lines):
    root = {}
    stack = [(0, root, None)]  # indent, container, last_key_in_map

    def container():
        return stack[-1][1]

    i = 0
    while i < len(lines):
        raw = lines[i].rstrip("\n")
        if not raw.strip() or raw.lstrip().startswith("#"):
            i += 1
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        while len(stack) > 1 and indent < stack[-1][0]:
            stack.pop()
        cur = container()
        s = raw.strip()
        if s.startswith("- "):
            rest = s[2:]
            if isinstance(cur, list):
                if ":" in rest and not rest.startswith("{"):
                    k, v = rest.split(":", 1)
                    item = {k.strip(): coerce(v)} if v.strip() else {k.strip(): {}}
                    if not v.strip():
                        stack.append((indent + 2, item[k.strip()] if False else item, k.strip()))
                    cur.append(item)
                else:
                    cur.append(coerce(rest))
            i += 1
            continue
        if ":" in s:
            k, v = s.split(":", 1)
            k = k.strip()
            v = v.strip()
            if not isinstance(cur, dict):
                i += 1
                continue
            if v == "":
                # peek next indent to decide list vs map
                nxt = None
                for j in range(i + 1, len(lines)):
                    peek = lines[j]
                    if peek.strip() and not peek.lstrip().startswith("#"):
                        nxt = peek
                        break
                if nxt and nxt.lstrip().startswith("- "):
                    cur[k] = []
                    stack.append((indent + 2, cur[k], None))
                else:
                    cur[k] = {}
                    stack.append((indent + 2, cur[k], None))
            else:
                cur[k] = coerce(v)
        i += 1
    return root

data = parse(text.splitlines())
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
  yaml_to_json "$fm" >"$js"
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
