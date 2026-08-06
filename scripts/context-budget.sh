#!/usr/bin/env bash
# context-budget.sh — Leseliste und Budget-Prüfung (LAW-CONTEXT).
# Quelle: manifest.json#/reading_lists + config/policy-defaults.json#/budgets|caps
# Exit: 0 PASS | 1 FAIL | 2 NICHT NACHGEWIESEN
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT}/manifest.json"
POLICY="${ROOT}/config/policy-defaults.json"
ALLOW_SKIP=0
EXTRA_COVERAGE=0
MODE=""
CLASS="" NODE="" ROLE=""
STATE=""

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
skip() { printf 'NICHT NACHGEWIESEN: %s\n' "$*" >&2; exit 2; }
need_jq() { command -v jq >/dev/null 2>&1 || skip "jq fehlt"; }

usage() {
  cat <<'EOF'
Usage:
  context-budget.sh --reading-list --class <k> --node <n> --role <r>
  context-budget.sh --check --state <path>
  context-budget.sh --max-bytes-per-agent
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reading-list) MODE=reading-list; shift ;;
    --check) MODE=check; shift ;;
    --max-bytes-per-agent)
      MODE=max-bytes
      shift
      # optional numeric arg from CI (ignored; value comes from policy)
      if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then shift; fi
      ;;
    --check-coverage) EXTRA_COVERAGE=1; shift ;;
    --class) CLASS="${2:-}"; shift 2 ;;
    --node) NODE="${2:-}"; shift 2 ;;
    --role) ROLE="${2:-}"; shift 2 ;;
    --state) STATE="${2:-}"; shift 2 ;;
    --allow-skip) ALLOW_SKIP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unbekanntes Argument: $1" ;;
  esac
done

need_jq
[[ -f "$MANIFEST" ]] || die "manifest.json fehlt"
[[ -f "$POLICY" ]] || die "policy-defaults.json fehlt"

resolve_anchor() {
  local key="$1"
  case "$key" in
    core) printf '%s\n' "AGENTS.md" ;;
    role-*)
      local role="${key#role-}"
      if [[ -f "${ROOT}/roles/${role}.md" ]]; then
        printf 'roles/%s.md\n' "$role"
      else
        die "Rollen-Karte fehlt: roles/${role}.md"
      fi
      ;;
    handover|handover-template)
      printf 'templates/handover.md\n'
      ;;
    module-*)
      local mod="${key#module-}"
      if [[ -f "${ROOT}/modules/${mod}.md" ]]; then
        printf 'modules/%s.md\n' "$mod"
      else
        die "Modul fehlt: modules/${mod}.md"
      fi
      ;;
    *)
      local path anchor
      path="$(jq -r --arg k "$key" '
        (.anchors // [])
        | map(select(.id == $k))
        | .[0].document // empty
      ' "$MANIFEST")"
      anchor="$(jq -r --arg k "$key" '
        (.anchors // [])
        | map(select(.id == $k))
        | .[0].anchor // empty
      ' "$MANIFEST")"
      if [[ -z "$path" ]]; then
        if [[ -f "${ROOT}/${key}" ]]; then
          printf '%s\n' "$key"
        else
          die "unbekannter Leseschlüssel: $key"
        fi
      else
        if [[ -n "$anchor" && "$anchor" != "null" ]]; then
          printf '%s#%s\n' "$path" "$anchor"
        else
          printf '%s\n' "$path"
        fi
      fi
      ;;
  esac
}

do_reading_list() {
  [[ -n "$CLASS" && -n "$NODE" && -n "$ROLE" ]] || die "--class --node --role erforderlich"
  local entry
  entry="$(jq -c --arg c "$CLASS" --arg n "$NODE" --arg r "$ROLE" '
    (.reading_lists // [])
    | map(select(
        ((.class == "*") or (.class == $c)) and
        ((.node == "*") or (.node == $n)) and
        ((.role == "*") or (.role == $r))
      ))
    | .[0] // empty
  ' "$MANIFEST")"
  if [[ -z "$entry" ]]; then
    # Minimal fallback: core + role card if exists
    printf 'AGENTS.md\n'
    if [[ -f "${ROOT}/roles/${ROLE}.md" ]]; then
      printf 'roles/%s.md\n' "$ROLE"
    fi
    return 0
  fi
  local keys
  keys="$(jq -r '.read[]' <<<"$entry")"
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    resolve_anchor "$k"
  done <<<"$keys"
}

do_check() {
  [[ -n "$STATE" && -f "$STATE" ]] || die "--state <path> erforderlich"
  local br fr tc tu ab
  br="$(jq -r '.budget.bytes_read // 0' "$STATE")"
  fr="$(jq -r '.budget.files_read // 0' "$STATE")"
  tc="$(jq -r '.budget.tool_calls // 0' "$STATE")"
  tu="$(jq -r '.budget.turns // 0' "$STATE")"
  ab="$(jq -r '.budget.artifact_bytes // 0' "$STATE")"
  local mbr mfr mtc mtu mab
  mbr="$(jq -r '.budgets.rotation.bytes_read_max' "$POLICY")"
  mfr="$(jq -r '.budgets.rotation.files_read_max' "$POLICY")"
  mtc="$(jq -r '.budgets.rotation.tool_calls_max' "$POLICY")"
  mtu="$(jq -r '.budgets.rotation.turns_max' "$POLICY")"
  mab="$(jq -r '.budgets.rotation.artifact_bytes_max' "$POLICY")"
  local fail=0
  printf 'budget check: bytes_read=%s/%s files_read=%s/%s tool_calls=%s/%s turns=%s/%s artifact_bytes=%s/%s\n' \
    "$br" "$mbr" "$fr" "$mfr" "$tc" "$mtc" "$tu" "$mtu" "$ab" "$mab"
  (( br > mbr )) && { printf 'FAIL bytes_read\n'; fail=1; }
  (( fr > mfr )) && { printf 'FAIL files_read\n'; fail=1; }
  (( tc > mtc )) && { printf 'FAIL tool_calls\n'; fail=1; }
  (( tu > mtu )) && { printf 'FAIL turns\n'; fail=1; }
  (( ab > mab )) && { printf 'FAIL artifact_bytes\n'; fail=1; }
  (( fail == 0 )) && printf 'PASS\n' && return 0
  return 1
}

do_max_bytes() {
  jq -r '.caps.read_bytes_per_delegation_max' "$POLICY"
}

do_coverage() {
  local missing=0 doc
  while IFS= read -r doc; do
    [[ -z "$doc" || "$doc" == "core" || "$doc" == "null" ]] && continue
    if [[ ! -f "${ROOT}/${doc}" ]]; then
      printf 'FAIL missing %s\n' "$doc"; missing=$((missing+1))
    fi
  done < <(jq -r '[.anchors[].document] | unique | .[]' "$MANIFEST")
  for mod in modules/*.md roles/*.md AGENTS.md; do
    [[ -f "$mod" ]] || { printf 'FAIL missing %s\n' "$mod"; missing=$((missing+1)); }
  done
  (( missing == 0 )) && printf 'PASS check-coverage\n'
  return $missing
}

rc=0
case "$MODE" in
  reading-list) do_reading_list || rc=1 ;;
  check) do_check || rc=1 ;;
  max-bytes) do_max_bytes || rc=1 ;;
  "") ;;
  *) usage; die "Modus fehlt" ;;
esac
if (( EXTRA_COVERAGE == 1 )); then
  do_coverage || rc=1
fi
if [[ -z "$MODE" && EXTRA_COVERAGE -eq 0 ]]; then usage; die "Modus fehlt"; fi
exit "$rc"
